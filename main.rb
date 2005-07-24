#!/usr/bin/env ruby
require 'libglade2'
require 'socket'
require 'rbconfig'
require 'base64'
require 'thread'
require 'monitor'
require "rexml/document"
$platform = RUBY_PLATFORM

$args = {}

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

$args.each do |k, v|
    puts k, v
end

#useful for debugging
Thread.abort_on_exception = true

class Object
    def deep_clone
        Marshal.load(Marshal.dump(self))
    end
end

def duration(seconds)
	if seconds < 0
		seconds *= -1
		negative = true
	end
	
	mins = (seconds / 60).floor.to_i
	secs = (seconds % 60).to_i
	hours = (mins/60).floor.to_i
	mins = (mins%60).to_i
	days = (hours/24).floor.to_i
	hours = (hours%24).to_i
	
	stuff = []
	
	stuff.push(secs.to_s+' Seconds')
	stuff.push( mins.to_s+' Minutes') if mins > 0
	stuff.push(hours.to_s+' Hours') if hours > 0
	stuff.push(days.to_s+' Days') if days > 0
	
	if stuff.length > 1
		result = stuff.pop+' '+stuff.pop
	else
		result = stuff[0]
	end
	
	result = ' - '+result if negative
	
	return result
end


#load all my home rolled ruby files here
require 'configuration'
require 'plugins'
require 'commandparser'
require 'eventparser'
require 'replyparser'
require 'tabcomplete'
require 'users'
require 'buffers'
require 'replies'
require 'connections'
require 'mainwindow'
require 'configwindow'
require 'connectionwindow'


class Main
	attr_reader :serverlist, :window, :replies, :connectionwindow, :drift
    @@test = 'no'
    extend Plugins
    include PluginAPI
    include EventParser
    include ReplyParser
    include CommandParser
	def initialize
		@serverlist = RootBuffer.new(self)
		@connection = nil
		@replies = {}
		@buffer = []
		@buffer[0] = true
		@filehandles = []
		@filedescriptors = {}
		@keys = {}
		@drift = 0
        @networks = []
        @presences = []
	end
    
    def test
        puts self.class.cb_hash.length
        #puts @@cb_hash.length
    end
    
	#start doing stuff
	def start
		Gtk.init
        reply_reaper
		@connectionwindow = ConnectionWindow.new
		@window = MainWindow.new
		if @connectionwindow.autoconnect == true
			@connectionwindow.start_connect
		end
		Gtk.main
	end
	
    def reply_reaper
        @reaperthread = Thread.new do
            while true
                sleep 5
                @replies.each do |key, reply|
                    if reply.complete
                        puts 'REAPING - reply '+reply.name+' is complete, parsing'
                        @replies.delete(key)
                        reply_parse(reply)
                    elsif (Time.new - reply.start).to_i > 10
                        puts 'REAPING - reply '+reply.name+' is incomplete and expired, resending'
                        @replies.delete(key)
                        send_command(key, reply.origcommand)
                    end
                end
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
	
	#escape the string
	def escape(string)
		result = string.gsub('\\', '\\\\\\')
		result.gsub!(';', '\\.')
		return result
	end
	
	#unescape the string
	def unescape(string)
		result = string.gsub('\\.', ';')
		result.gsub!('\\\\', '\\')
		return result
	end
    
    def escape_xml(string)
        #puts string
        s = string.gsub('<', '&lt;').gsub('>', '&gt;')
        #puts s
        return s
    end
	
    def syncchannels
        @syncchannels = true
        Thread.new do
            @serverlist.servers.each do |server|
                server.channels.each do |channel|
                    if !channel.usersync and channel.connected
                         send_command('listchan-'+server.name+channel.name, "channel names;network="+server.name+";channel="+channel.name+";mypresence="+server.presence)
                        while channel.usersync != true
                            sleep 1
                        end
                    end
                end
                
                server.channels.each do |channel|
                    if !channel.eventsync and channel.connected
                        send_command('events-'+server.name+channel.name, 'event get;end=*;limit=200;filter=&(channel='+channel.name+')(network='+server.name+')(mypresence='+server.presence+')(!(event=client_command_reply))')
                        while channel.eventsync != true
                            sleep 1
                        end
                    end
                end
            end
            @syncchannels = nil
        end
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
            elsif method == 'local'
                @connection = LocalConnection.new(settings, @connectionwindow)
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
			@window.draw_from_config
            #puts 'setting presence to '+@connectionwindow.presence
			$config.set_value('presence', @connectionwindow.presence)
            #puts $config['presence']
			@connectionwindow.destroy
			
			#if @serverlist.servers.length == 0
            send_command('networks', 'network list')
				#send_command('presences', 'presence list')
			#end
	end
	
	#what do do when we get disconnected from irssi2
	def disconnect
		@connection = nil
		@serverlist.servers.each{|server|
			server.disconnect
			server.channels.each {|channel|
				channel.disconnect
			}
		}
	end
	
	#connect to a network
	def network_add(name, protocol, address, port)
        unless @serverlist.get_network_by_name(name)
            send_command('addnet', "network add;network="+name+";protocol="+protocol)
            temp = "gateway add;host="+address+";network="+name
            temp += ";port="+port if port != '' and port
            send_command('addhost', temp)
            @networks.push(name)
        else
            #line= {'err' => 'Network '+network+' is already defined'}
            #@window.currentbuffer.send_event(line, ERROR)
            throw_error('Network '+network+' is already defined')
        end
	end
    
    def network_connect(network, presence)
        if !@serverlist.get_network_by_name(network)  and !@networks.include?(network)
            throw_error('Undefined network '+network)
        elsif !@serverlist[network, presence] and !@presences.include?([network, presence])
            throw_error('Undefined presence '+presence)
        else
            send_command('connect', "presence connect;network="+network+";mypresence="+presence)
        end
    end
    
    def presence_add(network, presence)
        #@networks.each {|network| puts network}
        if !@serverlist.get_network_by_name(network) and !@networks.include?(network)
            throw_error('Undefined network '+network)
        elsif @serverlist[network, presence] or @presences.include?([network, presence])
            #throw_error('Presence '+presence+' exists')
            return true #non-fatal
        else
            cmdstring = "presence add;mypresence="+presence+";network="+network
            if @keys[presence] and @keys[presence]['silc_pub']
            	cmdstring += ";pub_key="+@keys[presence]['silc_pub']+";prv_key="+@keys[presence]['silc_priv']
            	cmdstring += ";passphrase="+@keys[presence]['silc_pass'] if @keys[presence]['silc_pass']
            end
            
            cmdstring.gsub!("\n", "\\n")
            send_command('addpres', cmdstring)
            @presences.push([network, presence])
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
        line = {'err' => 'Client Error: '+error}
        buffer.send_user_event(line, ERROR)
    end
	
	def throw_message(message, buffer=@serverlist)
	line = {'msg' => 'Client Message: '+message}
	buffer.send_user_event(line, NOTICE)
	end
	
	#split by line and parse each line
	def parse_lines(string)
		lines = string.split("\n")
		
		for i in 0...lines.length
			handle_output(lines[i])
		end
	end
	
	#send a command to irssi2
	def send_command(tag, command, length=nil)
		if !@connection
			return
		end

		@replies[tag] = Reply.new(tag, command)
		
		if length
			cmdstr = '+'+length.to_s+';'+tag+';'+command+"\n"
		else
			cmdstr = tag+';'+command+"\n"
		end
		
        if $args['debug']
            puts(cmdstr)
        end

		sent = @connection.send(cmdstr)
		
		if !sent
			@connection = nil
			disconnect
			@connectionwindow = ConnectionWindow.new
		end
	end
	
	#handle output from irssi2
	def handle_output(string)
		return if string.length == 0
		line= {}
		re = /(^[^\*]+);([+\->]+)(.*)$/
		re2 = /^[*]+;([a-zA-Z_]+);(.+)$/
		
		if md = re.match(string)
			if @replies[$1]
				reply = @replies[$1]
				Thread.new{reply.addline(string)}
				if @replies[$1] and @replies[$1].complete
					Thread.new do
						reply_parse(reply)
						@replies.delete(reply.name)
					end
				end
			else
				#puts "Event for dead or unregistered handler recieved " + string
			end
			return
		elsif !md = re2.match(string)
			puts "Failed to match: "+string+"\n"
			return
		end
		line['event_type'] = $1
        line['original'] = string
		
		items = $2.split(';')
		
		items.each do |x|
			vals = x.split('=', 2)
			if vals[1] and vals[1] != ''
				line[vals[0]] = unescape(vals[1])
			elsif x.count('=') == 0
				line[x] = true
			end
		end
		calculate_clock_drift(line['time']) if line['time']
		
		if $config['canonicaltime'] == 'client'
			line['time'] = Time.at(line['time'].to_i + $main.drift)
		end
		
		num = line['id'].to_i
		@buffer[num] = line 
		
		if @last == nil
			@last = num-1
		end

		event_parse(@buffer[num])
	end
	
	#keep an eye on the difference between client & server time
	def calculate_clock_drift(servertime)
		server = Time.at(servertime.to_i)
		client = Time.new
		@drift = (client - server).to_i
	end
	
	#~ #create a network if it doesn't already exist
	#~ def createnetworkifnot(network, presence)
		#~ if ! @serverlist[network, presence]
			#~ switchchannel(@serverlist.add(network, presence))
		#~ end
		
		#~ return @serverlist[network, presence]
	#~ end
	
	#~ #create a channel if it doesn't already exist
	#~ def createchannelifnot(network, channel)
		#~ if network and ! network[channel]
			#~ switchchannel(network.add(channel))
		#~ elsif ! network
			#~ puts "ERROR: invalid network!"
			#~ return nil
		#~ end
		
		#~ return network[channel]
	#~ end
	
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
        
        line = {}
        line['err'] = err
        time = Time.new
        time = time - @drift if $config['canonicaltime'] == 'server'
        line['time'] = time
        target.send_event(line, ERROR)
    end
    
	#duh....
	def quit(send_quit = true)
		$config.send_config
        if send_quit
            send_command('quit', 'quit')
        end
		@connection.close if @connection
        @reaperthread.kill if @reaperthread
		puts 'bye byeeeeee...'
		exit
	end
end
#Main.test

#start the ball rolling...
begin
	$config = Configuration.new
	$main = Main.new
    #~ 10.times do
        #~ $main.plugin_load('osd')
        #~ sleep 2
        #~ Plugin.unregister(Plugin.lookup('osd'))
    #~ end
    #$main.test
	$main.start
rescue Interrupt
	puts 'got keyboard interrupt'
	$main.window.quit
	$main.quit
end

