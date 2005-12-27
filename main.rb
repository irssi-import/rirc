require 'libglade2'
require 'socket'
require 'rbconfig'
require 'base64'
require 'thread'
require 'monitor'
require 'yaml'
require 'scw'
require 'observer'
require 'contrib/orderedhash'
require 'iconv'
require 'pathname'
require 'utils'

if RUBY_PLATFORM.include?('win32') or RUBY_PLATFORM.include?('mingw32')
    $platform = 'win32'
    $rircfolder = ENV['APPDATA']+'/rirc'
else
    $platform = 'linux'
    $rircfolder = ENV['HOME']+'/.rirc'
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
#Thread.abort_on_exception = true


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
require 'plugins'
require 'commandparser'
require 'eventparser'
require 'replyparser'
require 'tabcomplete'
require 'users'
require 'bufferview'
require 'buffers'
require 'replies'
require 'connections'
require 'keybinding'
require 'mainwindow'
require 'tablist'
require 'configwindow'
require 'connectionwindow'
require 'networkpresenceconf'
require 'linkwindow'
require 'pluginwindow'

class Main
	attr_reader :serverlist, :window, :replies, :connectionwindow, :drift, :networks, :protocols, :quitting, :tabmodel
    #extend Plugins
    include PluginAPI
    include EventParser
    include ReplyParser
    #include CommandParser
    
    def initialize
        @tabmodel = TabListModel.new
        @serverlist = RootBuffer.new(self)
        @tabmodel.root=@serverlist
        #@tabmodel.set_sort_and_structure(*$config.gettabmodelconfig)
        @connection = nil
        @replies = {}
        @buffer = []
        @buffer[0] = true
        @filehandles = []
        @filedescriptors = {}
        @keys = {}
        @drift = 0
        @networks = ItemList.new(Network)
        @protocols = ItemList.new(Protocol)
        @quitting = false
        @inputqueue = MessageQueue.new
        @outputqueue = MessageQueue.new
        
        @inputwatcher = Watcher.new(@inputqueue) {|x| command_parse(*x)}
        @outputwatcher = Watcher.new(@outputqueue) {|x| handle_output(x)}
    end
    
    #start doing stuff
    def start
        Gtk.init
        reply_reaper
        @connectionwindow = ConnectionWindow.new unless @connectionwindow and @connectionwindow.open?
        @window = MainWindow.new
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
                        puts 'REAPING - reply '+reply.name+' is complete, parsing'
                        @replies.delete(key)
                        reply_parse(reply)
                    elsif (Time.new - reply.start).to_i > 15
                        puts (Time.new - reply.start).to_i, reply.name
                        #next
                        if reply.retries < 1
                            puts 'REAPING - reply '+reply.name+' is incomplete and expired, resending'
                            @replies.delete(key)
                            send_command(key, reply.origcommand)
                            @replies[key].retries = reply.retries+1
                        else
                            puts 'REAPING - reply '+reply.name+' has been retried twice, deleting'
                            @replies.delete(key)
                        end
                    end
                end
                sleep 5
            end
        end
    end
    
    #wrapper for window function
    def switchchannel(channel)
        @window.switchchannel(channel) if @window
    end
	
    #wrapper for window function
    def scroll_to_end(channel)
        @window.scroll_to_end(channel)
    end
    
    def syncchannels
        @syncchannels = true
        Thread.new do
            Thread.current.priority = -2
            @serverlist.servers.each do |server|
                #send_command('events-'+server.name, 'event get;end=*;limit=200;filter=&(network='+server.name+')(presence='+server.presence+')(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)(channel=*)(event=presence_status_changed)(event=client_command)(event=client_config_changed)(event=presence_init)(event=presence_deinit))')
                #send_command('events-'+server.name, 'event get;end=*;limit=200;filter=&(network='+server.name+')(presence='+server.presence+')(|(event=msg)(event=notice))(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)(channel=*))')
                server.channels.each do |channel|
                    if !channel.usersync and channel.connected
                        send_command('listchan-'+server.name+channel.name, "channel names;network="+server.name+";channel="+channel.name+";mypresence="+server.presence)
                        while !channel.usersync
                            #puts 'user sleeping', channel.name
                            sleep 2
                        end
                    end
                end
                
                server.channels.each do |channel|
                    if !channel.eventsync and channel.connected
                        send_command('events-'+server.name+channel.name, 'event get;end=*;limit=100;filter=&(channel='+channel.name+')(network='+server.name+')(mypresence='+server.presence+')(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)))(time>1)')
                        while !channel.eventsync
                            #puts 'event sleeping', channel.name
                            sleep 2
                        end
                    end
                end
                if server.connected
                    #send_command('events-'+server.name, 'event get;end=*;limit=200;filter=&(network='+server.name+')(mypresence='+server.presence+')(event=msg)(!(|(init=*)(deinit=*)(raw=*)(channel=*))')
                end
            end
        end
        @syncchannels = nil
    end
    
    #connect to irssi2
    def connect(method, settings)
        return if @connection
            @connectionwindow.send_text('Connecting...')
            begin
            if method == 'ssh'
                @connection = SSHConnection.new(settings, @connectionwindow)
            elsif method == 'socket'
                @connection = UnixSockConnection.new(settings, @connectionwindow)
            elsif method == 'inetd'
                @connection = InetdConnection.new(settings, @connectionwindow)
        elsif method == 'local'
            @connection = LocalConnection.new(settings, @connectionwindow)
        elsif method == 'net_ssh'
            @connection = NetSSHConnection.new(settings, @connectionwindow)
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
            
        $config.get_config
        
        $config['plugins'].each {|plugin| plugin_load(plugin)}
        #@tabmodel = TabListModel.new(@serverlist, *$config.gettabmodelconfig)
        @tabmodel.draw_tree
            @window.draw_from_config
        @window.drawuserlist(false)
        @serverlist.storedefault
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
    
    def throw_error(error, buffer=@serverlist)
        line = Line[ERR => 'Client Error: '+error]
        buffer.send_user_event(line, EVENT_ERROR)
    end
	
    def throw_message(message, buffer=@serverlist)
	line = Line[MSG => 'Client Message: '+message]
	buffer.send_user_event(line, EVENT_NOTICE)
    end
    
    def queue_input(msg)
        @inputqueue.enq(msg)
    end
    
    def queue_output(msg)
        @outputqueue.enq(msg)
    end
	
    #split by line and parse each line
    def parse_lines(string)
        lines = string.split("\n")
        
        lines.each do |line|
        $main.serverlist.send_user_event({'msg' =>line.chomp}, EVENT_NOTICE) if $args['debug']
            queue_output(line)
        end
    end
	
    #send a command to irssi2
    def send_command(tag, command, length=nil)
        if !@connection
            disconnect
            return
        end
    
        @replies[tag] = Reply.new(tag, command)
            
        if length
            cmdstr = '+'+length.to_s+';'+tag+';'+command+"\n"
        else
            cmdstr = tag+';'+command+"\n"
        end
    
        sent = @connection.send(cmdstr)
            
        if !sent
            @connection = nil
            disconnect
            @connectionwindow = ConnectionWindow.new unless @xonnectionwindow and @connectionwindow.open
        end
        return @replies[tag]
    end
	
    #handle output from irssi2
    def handle_output(string)
        #string = Iconv.new("UTF-8", "UTF-8//IGNORE").iconv(string)
        return if string.length == 0
        
        tag, event = string.split(';', 2)
        #~ re = /(^[^\*]+);([+\->]+)(.*)$/
        #~ re2 = /^[*]+;([a-zA-Z_]+);(.+)$/
        
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
            
            if $config['canonicaltime'] == 'client'
                line[:time] = Time.at(line[:time].to_i + $main.drift)
            end
            
            event_parse(line)
            #num = line[:id].to_i
            #@buffer[num] = line 
    
            #~ line.each do |k,v|
                #~ puts k,v
            #~ end
    
            #event_parse(@buffer[num])
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
        
        #~ if md = re.match(string)
            #~ if @replies[$1]
                #~ reply = @replies[$1]
                #~ Thread.new do
                    #~ #Thread.current.priority = -3
                    #~ reply.addline(string)
                #~ end
                #~ if @replies[$1] and @replies[$1].complete
                    #~ Thread.new do
                        #~ reply_parse(reply)
                        #~ @replies.delete(reply.name)
                    #~ end
                #~ end
            #~ end
            #~ return
        #~ elsif !md = re2.match(string)
            #~ puts "Failed to match: "+string+"\n"
            #~ return
        #~ end
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
        
        if network = @serverlist[network, presence]
            target = network
        elsif @serverlist[network, presence] and channel = @serverlist[network, presence][channel]
            target = channel
        else
            target = @serverlist
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
        
        target.send_user_event(Line['err' => err], EVENT_ERROR)
    end
    
    
    #duh....
    def quit
        #if the connection is dead, don't bother trying to comunicate with irssi2
        if !@connection
            @quitting = true
            do_quit
        
        #update the config and wait for quit response
        else
            @quitting = true
            $config.send_config
            send_command('quit', 'quit')
            puts 'sending quit (timeout 5 seconds...)'
            sleep 5
            unless @quit
                puts 'failed to get quit confirmation, doing it manually'
                do_quit
            end
        end
        true
    end
    
    def do_quit
        return unless @quitting
        @connection.close if @connection
        @reaperthread.kill if @reaperthread
        Gtk.main_quit
        puts 'bye byeeeeee...'
        exit
    end
end

