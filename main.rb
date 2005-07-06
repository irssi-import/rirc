#!/usr/bin/env ruby

require 'libglade2'
require 'socket'
require 'rbconfig'
require 'base64'
require 'thread'
require 'monitor'
include Config
puts CONFIG['target']

#puts ARGV

$args = {}

def parse_args
    args = ARGV
    args.each do |arg|
        #puts arg
        #~ if arg == '--debug'
            #~ puts 'debugging on'
            #~ $debug = true
        while arg[0].chr == '-'
            arg = arg[1, arg.length]
        end
        name, value = arg.split('=')
        if value
            $args[name] = value
        else
            $args[name] = true
        end
        #end
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
require 'lineparser'
require 'eventparser'
require 'inputparser'
require 'tabcomplete'
require 'users'
require 'buffers'
require 'events'
require 'connections'
require 'mainwindow'
require 'configwindow'
require 'connectionwindow'


class Main
	attr_reader :serverlist, :window, :events, :connectionwindow, :drift
    #include Plugins
    include LineParser
    include EventParser
    include InputParser
	def initialize
		@serverlist = RootBuffer.new(self)
		@connection = nil
		@events = {}
		@buffer = []
		@buffer[0] = true
		@filehandles = []
		@filedescriptors = {}
		@keys = {}
		@drift = 0
        @networks = []
        @presences = []
	end
    
	#start doing stuff
	def start
		Gtk.init
        event_reaper
		@connectionwindow = ConnectionWindow.new
		@window = MainWindow.new
		if @connectionwindow.autoconnect == true
			@connectionwindow.start_connect
		end
		Gtk.main
	end
	
    def event_reaper
        @reaperthread = Thread.new do
            #puts 'starting event reaper thread...'
            while true
                sleep 5
                @events.each do |key, event|
                    #puts (Time.new - event.start).to_i 
                    if (Time.new - event.start).to_i > 10
                        if event.complete
                            puts 'REAPING - event '+event.name+' is complete, parsing'
                             @events.delete(key)
                            handle_event(event)
                        else
                            puts 'REAPING - event '+event.name+' is incomplete and expired, resending'
                            @events.delete(key)
                            send_command(key, event.origcommand)
                        end
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
	
    def syncchannels
        @syncchannels = true
        Thread.new do
            @serverlist.servers.each do |server|
                server.channels.each do |channel|
                    if !channel.usersync
                         send_command('listchan-'+server.name+channel.name, "channel names;network="+server.name+";channel="+channel.name+";presence="+server.presence)
                        #puts 'usersyncing '+channel.name
                        while channel.usersync != true
                            sleep 1
                        end
                    end
                end
                
                server.channels.each do |channel|
                    if !channel.eventsync
                        send_command('events-'+server.name+channel.name, 'event get;end=*;limit=200;filter=&(channel='+channel.name+')(network='+server.name+')')
                        #puts 'eventsyncing '+channel.name
                        while channel.eventsync != true
                            sleep 1
                        end
                    end
                end
            end
            @syncchannels = nil
            #puts 'done'
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
			$config.set_value('presence', @connectionwindow.presence)
			@connectionwindow.destroy
			
			if @serverlist.servers.length == 0
				send_command('presences', 'presence list')
			end
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
        unless @networks.include?(name)
            send_command('addnet', "network add;network="+name+";protocol="+protocol)
            temp = "gateway add;host="+address+";network="+name
            temp += ";port="+port if port != '' and port
            send_command('addhost', temp)
            @networks.push(name)
        else
            puts 'Network exists'
        end
        #presence_add(presence, name)
		#send_command('connect', "presence connect;network="+name+";presence="+presence)
	end
    
    def network_connect(network, presence)
        if !@networks.include?(network)
            puts 'undefined network '+network
        elsif !@presences.include?([presence, network])
            puts 'undefined presence '+presence
        else
            send_command('connect', "presence connect;network="+network+";presence="+presence)
        end
    end
    
    def presence_add(network, presence)
        if !@networks.include?(network)
            puts 'undefined network '+network
        elsif @presences.include?([presence, network])
            puts 'Presence exists'
        else
            cmdstring = "presence add;presence="+presence+";network="+network
            #if protocol.downcase == 'silc' and @keys[presence] and @keys[presence]['silc_pub']
            #	cmdstring += ";pub_key="+@keys[presence]['silc_pub']+";prv_key="+@keys[presence]['silc_priv']
            #	cmdstring += ";passphrase="+@keys[presence]['silc_pass'] if @keys[presence]['silc_pass']
            #end
            #send_command('addpres', "presence add;name="+presence+";network="+name)
            #cmdstring.gsub!("\n", "\\n")
            #puts cmdstring
            send_command('addpres', cmdstring)
            @presences.push([presence, network])
        end
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
			#puts 'connection not initialized'
			return
		end
		
		#puts tag, command
		
		#puts 'added event for' + tag.to_s
		@events[tag] = Event.new(tag, command)
		
		if length
			cmdstr = '+'+length.to_s+';'+tag+';'+command+"\n"
		else
			cmdstr = tag+';'+command+"\n"
		end
		
        if $args['debug']
            puts(cmdstr)
        end
		#puts 'sent '+cmdstr
		sent = @connection.send(cmdstr)
		
		if !sent
			#puts 'failed to send'
			@connection = nil
			disconnect
			@connectionwindow = ConnectionWindow.new
		end
	end
	
	#handle output from irssi2
	def handle_output(string)
		return if string.length == 0
		#puts string
		line= {}
		re = /(^[^\*]+);([+\->]+)(.*)$/
		re2 = /^[*]+;([a-zA-Z_]+);(.+)$/
		
		if md = re.match(string)
			if @events[$1]
				#puts string
				#@events[$1]['raw_lines'].push(string)
				#puts @events[$1]
				event = @events[$1]
				Thread.new{event.addline(string)}
				if @events[$1] and @events[$1].complete
					#puts 'event '+$1+ ' complete'
					Thread.new do
						handle_event(event)
						@events.delete(event.name)
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
		line['type'] = $1
		
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

		parse_line(@buffer[num])
	end
	
	#keep an eye on the difference between client & server time
	def calculate_clock_drift(servertime)
		server = Time.at(servertime.to_i)
		client = Time.new
		@drift = (client - server).to_i
		#puts 'clock drift is '+duration(@drift)
	end
	
	#create a network if it doesn't already exist
	def createnetworkifnot(network, presence)
		if ! @serverlist[network, presence]
			switchchannel(@serverlist.add(network, presence))
		end
		
		return @serverlist[network, presence]
	end
	
	#create a channel if it doesn't already exist
	def createchannelifnot(network, channel)
		if network and ! network[channel]
			switchchannel(network.add(channel))
		elsif ! network
			puts "ERROR: invalid network!"
			return nil
		end
		
		return network[channel]
	end
	
    def handle_error(line, event)
        channel ||= event.command['channel']
        network ||= event.command['network']
        presence ||= event.command['presence']
        
        if network = @serverlist[network, presence]
            target = network
        elsif @serverlist[network, presence] and channel = @serverlist[network, presence][channel]
            target = channel
        else
            target = @serverlist
        end
        
        if line['bad']
            err = 'Bad line - '+event.origcommand
        elsif line['args']
            err = 'Bad arguments - '+event.origcommand
        elsif line['state']
            err = 'Bad state - '+event.origcommand
        elsif line['unknown']
            err = 'Unknown command - '+event.command['command']
        elsif line['nogateway']
            err = 'No gateway'
            err += ' for network - '+event.command['network'] if event.command['network']
        elsif line['noprotocol']
            err = 'Invalid Protocol'
            err += ' - '+event.command['protocol'] if event.command['protocol']
        elsif line['noconnection']
        elsif line['nonetwork']
            err = 'Invalid network'
            err += ' - '+event.command['network'] if event.command['network']
        elsif line['nopresence']
            err = 'Invalid or protected presence'
            err += ' - '+event.command['presence'] if event.command['presence']
        elsif line['exists']
            err ='Already Exists'
        elsif line['notfound']
            err = 'Not Found'
        elsif line['reply_lost']
            err = 'Reply to command - '+event.origcommand+' lost.'
        else
            puts 'unhandled error '+line['original']
            return
        end
        
        line = {}
        #puts err
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

#start the ball rolling...
begin
	$config = Configuration.new
	$main = Main.new
	$main.start
rescue Interrupt
	puts 'got keyboard interrupt'
	$main.window.quit
	$main.quit
end

