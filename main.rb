require 'libglade2'
require 'socket'
require 'rbconfig'
require 'base64'
require 'thread'
require 'monitor'
require 'yaml'
require 'scw'
require 'observer'
require 'pathname'

require 'utils'

if RUBY_PLATFORM.include?('win32') or RUBY_PLATFORM.include?('mingw32')
    $platform = 'win32'
    $rircfolder = File.join(ENV['APPDATA'], 'rirc')
else
    $platform = 'linux'
    $rircfolder = File.join(ENV['HOME'], '.rirc')
end

begin
    $:.unshift "lib"
    require 'net/ssh'
    $netssh = true
rescue LoadError
    $netssh = false
end

$args = {}

Thread.current.priority = 1

def parse_args
    args = ARGV
    args.each do |arg|
        while arg[0].chr == '-'
            arg = arg[1, arg.length]
        end
        name, value = arg.split('=')
        if value
            $args[name] = value
        else
            $args[name] = true
        end
    end
end

parse_args

#useful for debugging
Thread.abort_on_exception = true


class SingleWindow
    def open?
        return @open
    end

    def focus
        @window.present
    end
end


$:.unshift 'gtk'

#load all my home rolled ruby files here
require 'help'
require 'constants'
require 'queue'
require 'lines'
require 'configuration'
require 'items'
require 'bufferparser'
require 'plugins'
require 'aliases'
require 'commandparser'
require 'eventparser'
require 'replyparser'
require 'tabcomplete'
require 'users'
require 'userlistview'
require 'bufferview'
require 'commandbuffer'
#require 'buffers'
require 'networks'
require 'bufferlistview'
require 'replies'
require 'connections'
require 'keybinding'
require 'mainwindow'
require 'configwindow'
require 'connectionwindow'
require 'networkpresenceconf'
require 'linkwindow'
require 'pluginwindow'

class Main
    attr_reader :windows, :replies, :connectionwindow, :drift, :config, :console, :networks, :protocols, :buffers
    #extend Plugins
    include PluginAPI
    include EventParser
    include ReplyParser
    #include CommandParser

    def initialize
        @connection = nil
        @replies = {}
        @buffer = []
        @buffer[0] = true
        #hah awesome, look at that diagonal line of =s
        @keys = {}
        @drift = 0
        @config = Configuration.new
        @windows = []
        @networks = ItemList.new(Network)
        @protocols = ItemList.new(Protocol)
        @inputqueue = MessageQueue.new
        @outputqueue = MessageQueue.new
        @console = ConsoleBuffer.new(self)

        @buffers = {}
        @inputwatcher = Watcher.new(@inputqueue) {|x| command_parse(*x)}
        @outputwatcher = Watcher.new(@outputqueue) {|x| handle_output(x)}
        Plugin.main = self
        #         Plugin.class_eval{@@main = 'bambams'}
        #         puts Plugin.class_variables
        #         puts Plugins.methods

        #         Plugins.main = self
    end

    # start the GUI
    def start
        Gtk.init
        reply_reaper
        @connectionwindow = ConnectionWindow.new(self) unless @connectionwindow and @connectionwindow.open?
        if @connectionwindow.autoconnect == true
            @connectionwindow.start_connect
        end
        Gtk.main
    end

    def reply_reaper
        @reaperthread = Thread.new do
            Thread.current.priority = -3
            while true
                @replies.each do |key, reply|
                    if reply.complete
                        @replies.delete(key)
                        reply_parse(reply)
                    elsif (Time.new - reply.start).to_i > 15
                        if reply.retries < 1
                            @replies.delete(key)
                            send_command(key, reply.origcommand)
                            @replies[key].retries = reply.retries+1
                        else
                            @replies.delete(key)
                        end
                    end
                end
                sleep 5
            end
        end
    end

    def syncchannels
        @syncchannels = true
        Thread.new do
            Thread.current.priority = -2
            @windows.each do |win|
                win.buffers.channels.each do |channel|
                    if !channel.usersync and channel.joined?
                        send_command('listchan-'+channel.network.name+channel.name, "channel names;network="+channel.network.name+";channel="+channel.name+";mypresence="+channel.presence)
                        while !channel.usersync
                            sleep 2
                        end
                    end
                end

                win.buffers.channels.each do |channel|
                    if !channel.eventsync and channel.joined?
                        send_command('events-'+channel.network.name+channel.name, 'event get;end=*;limit=100;filter=&(channel='+channel.name+')(network='+channel.network.name+')(mypresence='+channel.presence+')(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)))(time>1)')
                        while !channel.eventsync
                            sleep 2
                        end
                    end
                end

                #~ @serverlist.servers.each do |server|
                #~ server.channels.each do |channel|
                #~ if !channel.usersync and channel.connected
                #~ send_command('listchan-'+server.name+channel.name, "channel names;network="+server.name+";channel="+channel.name+";mypresence="+server.presence)
                #~ while !channel.usersync
                #~ sleep 2
                #~ end
                #~ end
                #~ end

                #~ server.channels.each do |channel|
                #~ if !channel.eventsync and channel.connected
                #~ send_command('events-'+server.name+channel.name, 'event get;end=*;limit=100;filter=&(channel='+channel.name+')(network='+server.name+')(mypresence='+server.presence+')(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)))(time>1)')
                #~ while !channel.eventsync
                #~ sleep 2
                #~ end
                #~ end
                #~ end
                #~ if server.connected
                #~ end
                #~ end
            end
        end
        @syncchannels = nil
    end

    #~ #find what controller/buffer to send to, tries to cache for faster lookups
    #~ def dispatch(*key)

    #~ if key[2]
    #~ testkey = key[0..2]
    #~ elsif key[3]
    #~ testkey = [key[0], key[1], key[3]]
    #~ else
    #~ testkey = key[0..1]
    #~ end

    #~ result = @bufferlookup[testkey] if @bufferlookup.has_key? testkey
    #check for buffer that isn't a child of anything and remove it from the hash...
    #~ return result if !result.nil?

    #~ @windows.each do |window|
    #~ #puts window
    #~ if key[2]
    #~ key = key[0..2]
    #~ target = window.buffers.find_channel(*key)
    #~ elsif key[3]
    #~ key = [key[0], key[1], key[3]]
    #~ target = window.buffers.find_chat(*key)
    #~ else
    #~ key = key[0..1]
    #~ target = window.buffers.find_network(*key)
    #~ end
    #~ #puts target, key.inspect
    #~ if target
    #~ @bufferlookup[key] = target
    #~ puts "matched #{target} for #{key.inspect}"
    #~ return target
    #~ end
    #~ end
    #~ nil
    #~ end
    def restyle
        even = @config['scw_even'].to_hex
        odd = @config['scw_odd'].to_hex

        #         puts even, odd

        Gtk::RC.parse_string("style \"scwview\" {\
                         ScwView::even-row-color = \"#{even}\"\
                         ScwView::odd-row-color = \"#{odd}\"\
                         ScwView::column-spacing = 5\
                         ScwView::row-padding = 2\
                         }\n\
                         widget \"*.ScwView\" style \"scwview\"")

    end

    def remove_buffer(buffer)
        @buffers.delete_if{|k,v| v == buffer}
    end

    def add_buffer(*key)
        if buffer = find_buffer(*key)
            return buffer
        end
        #puts key.inspect
        if key[2]
            testkey = key[0..2]
            if network = find_buffer(*key[0..1])
                buffer = ChannelBuffer.new(key[2], network, self)
            else
                puts "undefined network #{key[0..1].inspect}"
            end
        elsif key[3]
            testkey = [key[0], key[1], key[3]]
            if network = find_buffer(*key[0..1])
                buffer = ChatBuffer.new(key[3], network, self)
            else
                puts "undefined network #{key[0..1].inspect}"
            end
        else
            testkey = key[0..1]
            buffer = NetworkBuffer.new(key[0], key[1], self)
        end
        #puts buffer
        assign_buffer_to_window(buffer) if buffer
        @buffers[testkey] = buffer
        buffer
    end

    def find_buffer(*key)
        if key[2]
            testkey = key[0..2]
        elsif key[3]
            testkey = [key[0], key[1], key[3]]
        else
            testkey = key[0..1]
        end

        @buffers[testkey]
    end

    def assign_buffer_to_window(buffer)
        #TODO - filter to allow intelligent buffer assignment
        @windows[0].buffers.add_buffer(buffer)#if @windows[0]
    end

    def reassign_buffer_to_window(buffer, window)
        #TODO
    end

    #connect to irssi2
    def connect(method, settings)
        return if @connection
        @connectionwindow.send_text('Connecting...')
        begin
            if method == 'ssh'
                @connection = SSHConnection.new(self, settings, @connectionwindow)
            elsif method == 'socket'
                @connection = UnixSockConnection.new(self, settings, @connectionwindow)
            elsif method == 'inetd'
                @connection = InetdConnection.new(self, settings, @connectionwindow)
            elsif method == 'local'
                @connection = LocalConnection.new(self, settings, @connectionwindow)
            elsif method == 'net_ssh'
                @connection = NetSSHConnection.new(self, settings, @connectionwindow)
            else
                @connectionwindow.send_text('invalid connection method')
                return
            end                
        rescue IOError
            @connectionwindow.send_text("Error: "+$!)
            return
        end

        @connectionwindow.send_text("Connected to irssi2!")
        @connection.listen(self)

        #@config.get_config
        unless $args['noconfig']
            send_command('getconfig', 'config get;*')
            while @replies['getconfig']
                sleep 1
            end
        end
        restyle
        @console.buffer.redraw

        @config['plugins'].each {|plugin| plugin_load(plugin)}
        @config['plugins'] = Plugin.list.values.map{|x| x['name']}#trim any plugins that failed to load
        @config['windows'].each do |hash|
            window = MainWindow.new(self, hash)
            @windows.push(window)
            window.draw_from_config
        end
        #@tabmodel = TabListModel.new(@serverlist, *$config.gettabmodelconfig)
        #@tabmodel.draw_tree
        #@window.draw_from_config
        #@window.drawuserlist(false)
        #@serverlist.storedefault
        @connectionwindow.destroy

        send_command('protocols', 'protocol list')
    end

    #what do do when we get disconnected from irssi2
    def disconnect
        @connection.close if @connection
        @connection = nil
        @serverlist.servers.each do |server|
            server.disconnect
            server.channels.each {|channel| channel.disconnect}
        end
        @connectionwindow = ConnectionWindow.new unless @connectionwindow and @connectionwindow.open?
    end

    #connect to a network
    def network_add(name, protocol, address, port)
        unless @serverlist.get_network_by_name(name)
            send_command('addnet', "network add;network="+name+";protocol="+protocol)
            temp = "gateway add;host="+address+";network="+name
            temp += ";port="+port if port != '' and port
            send_command('addhost', temp)
            @networks.add(name, protocol)
        else
            throw_error('Network '+network+' is already defined')
        end
    end

    def network_connect(network, presence)
        if !@serverlist.get_network_by_name(network)  and !@networks[network]
            throw_error('Undefined network '+network)
        elsif !@serverlist[network, presence] and !@networks[network].presences[presence]
            throw_error('Undefined presence '+presence)
        else
            send_command('connect', "presence connect;network="+network+";mypresence="+presence)
        end
    end

    def presence_add(network, presence)
        if !@serverlist.get_network_by_name(network) and !@networks[network]
            throw_error('Undefined network '+network)
        elsif @serverlist[network, presence] or @networks[network].presences[presence]
            return true
        else
            cmdstring = "presence add;mypresence="+presence+";network="+network
            if @keys[presence] and @keys[presence]['silc_pub']
                cmdstring += ";pub_key="+@keys[presence]['silc_pub']+";prv_key="+@keys[presence]['silc_priv']
                cmdstring += ";passphrase="+@keys[presence]['silc_pass'] if @keys[presence]['silc_pass']
            end

            cmdstring.gsub!("\n", "\\n")
            send_command('addpres', cmdstring)
            @networks[network].add_presence(presence)
            return true
        end
        return false
    end

    def channel_add(network, presence, channel)
        if @serverlist[network, presence] and channel
            send_command('add', 'channel add;network='+network+';mypresence='+presence+';channel='+channel)
        else
            throw_error('Invalid Network')
        end
    end

    def throw_error(error, buffer=@console)
        line = Line[ERR => 'Client Error: '+error]
        buffer.send_user_event(line, EVENT_ERROR)
    end

    def throw_message(message, buffer=@console)
        line = Line[MSG => 'Client Message: '+message]
        @console.send_user_event(line, EVENT_NOTICE)
    end

    def queue_input(msg)
        @inputqueue.enq(msg)
    end

    def queue_output(msg)
        @outputqueue.enq(msg)
    end

    def parse_line(line)
        @console.send_user_event({'msg' =>line.chomp}, EVENT_NOTICE) if $args['debug']
        queue_output(line)
    end

    #split by line and parse each line
    def parse_lines(lines)
        #         puts 'parsing lines'
        #         lines = string.split("\n")
        #         puts lines.inspect
        lines.each do |line|
            @console.send_user_event({'msg' =>line.chomp}, EVENT_NOTICE) if $args['debug']
            queue_output(line)
        end
    end

    #send a command to irssi2
    def send_command(tag, command, length=nil)
        if !@connection
            disconnect
            return
        end

        @replies[tag] = Reply.new(self, tag, command)

        if length
            cmdstr = '+'+length.to_s+';'+tag+';'+command+"\n"
        else
            cmdstr = tag+';'+command+"\n"
        end

        puts "[SENT] #{cmdstr}" if $args['debug']

        sent = @connection.send(cmdstr)

        if !sent
            @connection = nil
            disconnect
            @connectionwindow = ConnectionWindow.new unless @connectionwindow and @connectionwindow.open
        end
        return @replies[tag]
    end

    #handle output from irssi2
    def handle_output(string)
        return if string.length == 0

        tag, event = string.split(';', 2)

        #its an event
        if tag == '*'
            type, event = event.split(';', 2)
            #puts type, event
            line= Line.new

            line[:event_type] = type
            line['original'] = string

            items = event.split(';')

            items.each do |x|
                vals = x.split('=', 2)
                if vals[1] and vals[1] != ''
                    line[vals[0].to_sym] = unescape(vals[1])
                elsif x.count('=') == 0
                    line[x.to_sym] = true
                end
            end
            calculate_clock_drift(line['time']) if line['time']

            if @config['canonicaltime'] == 'client'
                line[:time] = Time.at(line[:time].to_i + @drift)
            end

            event_parse(line)
            #its a reply
        else
            if @replies[tag]
                reply = @replies[tag]
                Thread.new do
                    #Thread.current.priority = -3
                    reply.addline(string)
                end
                if @replies[tag] and @replies[tag].complete
                    Thread.new do
                        reply_parse(reply)
                        @replies.delete(reply.name)
                    end
                end
            end
            return
        end
    end

    #keep an eye on the difference between client & server time
    def calculate_clock_drift(servertime)
        server = Time.at(servertime.to_i)
        client = Time.new
        @drift = (client - server).to_i
    end

    def handle_error(line, reply)
        channel ||= reply.command['channel']
        network ||= reply.command['network']
        presence ||= reply.command['mypresence']

        puts line
        return

        if network = assign_window.buffers.find_network(network, presence)
            target = network
        elsif @serverlist[network, presence] and channel = @serverlist[network, presence][channel]
            target = channel
        else
            target = @window.networks.console
        end

        if line['bad']
            err = 'Bad line - '+reply.origcommand
        elsif line['args']
            err = 'Bad arguments - '+reply.origcommand
        elsif line['state']
            err = 'Bad state - '+reply.origcommand
        elsif line['unknown']
            err = 'Unknown command - '+reply.command['command']
        elsif line['nogateway']
            err = 'No gateway'
            err += ' for network - '+reply.command['network'] if reply.command['network']
        elsif line['noprotocol']
            err = 'Invalid Protocol'
            err += ' - '+reply.command['protocol'] if reply.command['protocol']
        elsif line['noconnection']
        elsif line['nonetwork']
            err = 'Invalid network'
            err += ' - '+reply.command['network'] if reply.command['network']
        elsif line['nopresence']
            err = 'Invalid or protected presence'
            err += ' - '+reply.command['mypresence'] if reply.command['mypresence']
        elsif line['exists']
            err ='Already Exists'
        elsif line['notfound']
            err = 'Not Found'
        elsif line['reply_lost']
            err = 'Reply to command - '+reply.origcommand+' lost.'
        else
            puts 'unhandled error '+line['original']
            return
        end

        @window.networks.send_user_event(target, Line['err' => err], EVENT_ERROR)
    end

    def quit
        #if the connection is dead, don't bother trying to comunicate with irssi2
        if !@connection
            do_quit

            #update the config and wait for quit response
        else
            send_command('sendconfig', @config.changes)
            send_command('quit', 'quit')
            #             puts 'sending quit (timeout 5 seconds...)'
            #             sleep 5
            #             unless @quit
            #                 puts 'failed to get quit confirmation, doing it manually'
            #                 do_quit
            #             end
        end
        true
    end

    def do_quit
        @connection.close if @connection
        @reaperthread.kill if @reaperthread
        Gtk.main_quit
        puts 'bye byeeeeee...'
        exit
    end
end

