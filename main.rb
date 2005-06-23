#!/usr/bin/env ruby

require 'libglade2'
require 'socket'
require 'rbconfig'
require 'base64'
include Config
puts CONFIG['target']

#$:.push('./lib')

#~ begin
	#~ require 'config'
#~ rescue LoadError
	#~ puts "Cannot load config.rb, please rename and edit config.rb.factory"
	#~ exit
#~ end

#if $method == 'ssh'
#	require 'net/ssh'
#end

#useful for debugging
Thread.abort_on_exception = true

 #fuck signals, lets just extend the button class to hold a reference to its parent object
 module Parent
	attr :channel;
	def setchannel(channel)
		@channel = channel
	end
end

class Object
    def deep_clone
        Marshal.load(Marshal.dump(self))
    end
end

module Gtk
	class ToggleButton
		#load the mixin
		include Parent
	end
end

def duration(seconds)

	mins = (seconds / 60).floor
	secs = seconds % 60
	hours = (mins/60).floor
	mins = mins%60
	days = (hours/24).floor
	hours = hours%24
	
	stuff = []
	
	stuff.push(secs.to_s+' Seconds')
	stuff.push( mins.to_s+' Minutes') if mins > 0
	stuff.push(hours.to_s+' Hours') if hours > 0
	stuff.push(days.to_s+' Days') if days > 0
	
	if stuff.length > 1
		return stuff.pop+' '+stuff.pop
	else
		return stuff[0]
	end
end

	

$counter = 0

class Configuration
	def initialize
		#set some defaults... probably too soon be overriden by the user's config, but you gotta start somewhere :P
		@values = {}
		@values['color0'] = Gdk::Color.new(62168, 16051, 16051)
		@values['color1'] = Gdk::Color.new(0, 47254, 11392)
		@values['color2'] = Gdk::Color.new(0, 28332, 65535)
		@values['color3'] = Gdk::Color.new(65535, 65535, 0)
		@values['color4'] = Gdk::Color.new(65535, 0, 65535)
		@values['color5'] = Gdk::Color.new(0, 65535, 65535)
		
		@values['backgroundcolor'] = Gdk::Color.new(65535, 65535, 65535)
		@values['foregroundcolor'] = Gdk::Color.new(0, 0, 0)
		@values['selectedbackgroundcolor'] = Gdk::Color.new(13208, 44565, 62638)
		@values['selectedforegroundcolor'] = Gdk::Color.new(65535, 65535, 65535)

		@values['neweventcolor'] = Gdk::Color.new(45535, 1000, 1000)
		@values['newmessagecolor'] = Gdk::Color.new(65535, 0, 0)
		@values['highlightcolor'] = Gdk::Color.new(0, 0, 65535)
		
		@statuscolors = [Gdk::Color.new(0, 0, 0), @values['neweventcolor'], @values['newmessagecolor'], @values['highlightcolor']]
		
		@values['usetimestamp'] = false
		@values['timestamp'] = "[%H:%M]"
		@values['message'] = "%2<%2%u%2>%2 %m"
		@values['usermessage'] = "%4<%4%u%4>%4 %m"
		@values['action'] = "%1*%1%u %m"
		@values['notice'] = "-%1--%1 %m"
		@values['error'] = "%0***%0 %m"
		@values['join'] = "-%1->%1 %u (%1%h%1) has joined %c"
		@values['userjoin'] = "-%1->%1 You are now talking on %c"
		@values['part'] = "<%1--%1 %u (%1%h%1) has left %c (%r)"
		@values['userpart'] = "<%1--%1 You have left %c"
		@values['whois'] = "%2[%2%n%2]%2 %m"
		
		@values['linkclickaction'] = 'firefox %s'
		
		@serverbuttons = true
		
		@values['channellistposition'] = 'bottom'
		
		@values['commandbuffersize'] = 10
		
		@values['presence'] = 'vag'
		
		@oldvalues = {}
	end
	
	#converts status into a color
	def getstatuscolor(status)
		return @statuscolors[status]
	end
	
	def [](value)
		return get_value(value)
	end
	
	def get_all_values
		return @values
	end
	
	def get_value(value)
		if @values.values
			return @values[value]
		else
			return false
		end
	end
	
	def set_value(key, value)
		@values[key] = value
	end
	
	def send_config
		cmdstring = ''
		
		@values.each do |k, v|
			value = encode_value(v)
			if @oldvalues[k] != value or  !@oldvalues[k]
				cmdstring += ';rirc_'+k+'='+value if k and value
				#puts k+" HAS changed"
			else
				#puts k+' has not changed'
			end
		end
		
		if cmdstring == ''
			#puts 'no changes'
		else
			cmdstring = 'config set'+cmdstring
		end
		
		$main.send_command('sendconfig', cmdstring)
	end
	
	def get_config
		$main.send_command('getconfig', 'config get;*')
		while $main.events['getconfig']
			sleep 1
		end
	end
	
	def encode_value(value)
		if value.class == Gdk::Color
			colors = value.to_a
			return 'color:'+colors[0].to_s+':'+colors[1].to_s+':'+colors[2].to_s
		elsif value.class == String
			return value
		elsif value == true
			return 'true'
		elsif value == false
			return 'false'
		else
			return value.to_s
		end
	end
	
	def decode_value(value)
		#puts value
		if value =~ /^color\:(\d+)\:(\d+)\:(\d+)$/
			#puts value+' is a color'
			return Gdk::Color.new($1.to_i, $2.to_i, $3.to_i)
		elsif value == 'true'
			return true
		elsif value == 'false'
			return false
		else
			return value
		end
	end
	
	def parse_config(event)
		event.lines.each do |line| 
			if line['key'] and line['value']
				#puts line['key']+' is '+line['value']
				value = decode_value(line['value'])
				@values[line['key'].sub('rirc_', '')] = value
			end
		end
		
		create_config_snapshot
	end
	
	def create_config_snapshot
		@values.each do |k, v|
			@oldvalues[k.deep_clone] = encode_value(v)
		end
	end
		
end

#load all my home rolled ruby files here
require 'users'
require 'buffers'
require 'events'
require 'connections'
require 'mainwindow'
require 'configwindow'
require 'connectionwindow'


class Main
	attr_reader :serverlist, :window, :events, :connectionwindow
	def initialize
		@serverlist = RootBuffer.new(self)
		@connection = nil
		@events = {}
		@buffer = []
		@buffer[0] = true
		@filehandles = []
		@filedescriptors = {}
		@keys = {}
	end
	
	def start
		Gtk.init
		@connectionwindow = ConnectionWindow.new
		@window = MainWindow.new
		if @connectionwindow.autoconnect == true
			@connectionwindow.start_connect
		end
		Gtk.main
	end
	
	def switchchannel(channel)
		@window.switchchannel(channel) if @window
	end
	
	def scroll_to_end(channel)
		@window.scroll_to_end(channel)
	end
	
	def escape(string)
		result = string.gsub('\\', '\\\\\\')
		result.gsub!(';', '\\.')
		return result
	end
	
	def unescape(string)
		result = string.gsub('\\.', ';')
		result.gsub!('\\\\', '\\')
		return result
	end
	
	def connect(method, settings)
		return if @connection
		#Thread.start{
			@connectionwindow.send_text('Connecting...')
			begin
			if method == 'ssh'
				@connection = SSHConnection.new(settings, @connectionwindow)
			elsif method == 'socket'
				@connection = UnixSockConnection.new(settings, @connectionwindow)
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
			
			if @serverlist.servers.length > 0
				#~ @serverlist.servers.each{|server|
					#~ connectnetwork(server.name, server.address, server.presence
					#~ server.channels.each {|channel|
						#~ channel.disconnect
					#~ }
				#~ }
			else
				#puts 'requesting presence list'
				send_command('presences', 'presence list')
			end
		#}
	end
	
	def disconnect
		@connection = nil
		#puts 'doing global disconnect'
		@serverlist.servers.each{|server|
			server.disconnect
			server.channels.each {|channel|
				channel.disconnect
			}
		}
		#sleep 5#prevent flooding the server with reconnect requests
	end
	
	def connectnetwork(name, protocol, address, port,  presence)
		send_command('addnet', "network add;name="+name+";protocol="+protocol)
		cmdstring = "presence add;name="+presence+";network="+name
		if protocol.downcase == 'silc' and @keys[presence] and @keys[presence]['silc_pub']
			cmdstring += ";pub_key="+@keys[presence]['silc_pub']+";prv_key="+@keys[presence]['silc_priv']
			cmdstring += ";passphrase="+@keys[presence]['silc_pass'] if @keys[presence]['silc_pass']
		end
		#send_command('addpres', "presence add;name="+presence+";network="+name)
		cmdstring.gsub!("\n", "\\n")
		puts cmdstring
		send_command('addpres', cmdstring)
		temp = "gateway add;host="+address+";network="+name
		temp += ";port="+port if port != '' and port
		send_command('addhost', temp)
		send_command('connect', "presence connect;network="+name+";presence="+presence)
	end
		
	def parse_lines(string)
		lines = string.split("\n")
		
		for i in 0...lines.length
			handle_output(lines[i])
		end
	end
  
	def handle_input(message, channel, network, presence)
		command, arguments = message.split(' ', 2)
		
		arguments = '' if ! arguments

		if command == '/join' and network
			send_command('join', "channel join;network="+network+";channel="+arguments)
		elsif command == '/server' and  arguments  =~ /^([a-zA-Z0-9_\-]+):([a-zA-Z]+):([a-zA-Z0-9_.\-]+)(?:$|:(\d+))/
			#puts $1, $2, $3, $4, presence
			connectnetwork($1, $2, $3, $4, presence)
		elsif command == '/part'
			arguments = arguments.split(' ')
			if arguments[0]
				send_command('part', "channel part;network="+network+";presence="+$config['presence']+";channel="+arguments[0])
			else
				line = {}
				line['err'] = 'Part requires a channel argument'
				line['time'] = Time.new.to_i
				@window.currentbuffer.send_event(line, ERROR)
			end
		elsif command == '/quit'
			send_command('quit', 'quit')
			Gtk.main_quit
		elsif command == '/shutdown'
			send_command('shutdown', 'shutdown')
			Gtk.main_quit
		elsif command == '/silckey' and arguments =~ /^(.+) (.+)( (.+)|)$/
			#puts $1, $2, $3
			pub = $1
			priv = $2
			pass = $3
			if pub and priv
				key_pub = pub.to_s.sub('~', ENV['HOME'])
				key_priv = priv.to_s.sub('~', ENV['HOME'])
				
				if File.file?(key_pub) and File.file?(key_priv)
					@keys[$config['presence']] = {'silc_pub' => IO.read(key_pub),
												'silc_priv' => Base64.encode64(IO.read(key_priv))}
					@keys[$config['presence']]['silc_pass'] = pass if pass.length > 0
					
					#@keys[$config['presence']].each do |k, v|
					#	puts k+' '+v
					#end
				else
					puts 'file not found'
				end
			end
			
		elsif command == '/send'
			if arguments[0] == '~'[0]
				arguments.sub!('~', ENV['HOME'])#expand ~
			end
			#puts arguments +' exists' if File.file?(arguments)
			name, path = arguments.reverse.split('/', 2)
			name.reverse!
			path = '' if !path
			path.reverse!
			@filedescriptors[name] = File.open(arguments, 'r') # create a file descriptor with a key the same as the filename sent to server
			#puts @filedescriptors[name]
			send_command('file send '+name, 'file send;resume;name='+name+';size='+File.size(arguments).to_s)
		elsif command == '/ruby'
			puts 'possibly evil ruby code inputted, blindly executing'
			eval(arguments)
		elsif command == '/raw'
			#puts 'sending '+arguments
			output = {}
			output['msg'] = 'Sent raw command "'+arguments+'" to irssi2 directly'
			@serverlist.send_event(output, NOTICE)
			send_command('raw', arguments)
		elsif command == '/nick'
			name, bleh = arguments.split(' ', 2)
			send_command('nick'+name, 'presence change;network='+network+';presence='+presence+';new_name='+name)
		elsif command == '/whois'
			name, bleh = arguments.split(' ', 2)
			send_command('whois'+name, 'presence status;network='+network+';presence='+presence+';name='+name)
		elsif command == '/msg'
			arguments = arguments.split(' ', 2)
			if arguments[0] and arguments[1]
				messages = arguments[1].split("\n")
				messages.each { |message|
					send_command('msg'+rand(100).to_s, 'msg;network='+network+';nick='+arguments[0]+';msg='+message+";presence="+presence)
				}
			else
				line = {}
				line['err'] = '/msg requires a username and a message'
				line['time'] = Time.new.to_i
				@window.currentbuffer.send_event(line, ERROR)
			end
		elsif network
			messages = message.split("\n")
			messages.each { |message|

				send_command('message'+rand(100).to_s, 'msg;network='+network+';channel='+channel+';msg='+escape(message)+";presence="+presence)
				line = {}
				line['nick'] = presence
				line['msg'] = message
				line['time'] = Time.new.to_i
				@window.currentbuffer.send_event(line, USERMESSAGE)			}
		elsif !network
			line = {}
			line['err'] = 'Invalid server command'
			line['time'] = Time.new.to_i
			@window.currentbuffer.send_event(line, ERROR)
		end
	end
	
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
		
		#puts 'sent '+cmdstr
		sent = @connection.send(cmdstr)
		
		if !sent
			#puts 'failed to send'
			@connection = nil
			disconnect
			@connectionwindow = ConnectionWindow.new
		end
	end
	
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
				if @events[$1].complete
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
		
		num = line['id'].to_i
		@buffer[num] = line 
		
		if @last == nil
			@last = num-1
		end

		parse_line(@buffer[num])

	end
	
	def handle_event(event)
		
		#puts 'handling '+event.name
			
		
		if event.command['command'] == 'presence status'
			whois(event)
			return
		elsif event.command['command'] == 'config get'
			$config.parse_config(event)
			return
		end
		
		event.lines.each do |line|
			
			if event.name == 'raw'
				output = {}
				output['msg'] =  line['original']
				@serverlist.send_event(output, NOTICE)
				next
			end
			
			if line['status'] == '-'
				line['err'] = 'Error: '+line['error']+' encountered when sending command '+event.origcommand
				@serverlist.send_event(line, ERROR)
				return
			end
			
			if line['status'] == '+'
				if event.command['command'] == 'channel names'
					puts 'end of user list'
					@serverlist[event.command['network'], event.command['presence']][event.command['channel']].drawusers
					@window.updateusercount
				end
			end
			
			if event.command['command'] == 'file send'
				#puts line['original']
				if line['closed'] and @filehandles[line['handle'].to_i]
					puts 'file sent'
					@filehandles[line['handle'].to_i].close
					@filehandles.delete_at(line['handle'].to_i)
					return
				end
				#puts line['original']
				if event.command['name']
					@filehandles[line['handle'].to_i] = @filedescriptors[event.command['name']]
				end
				
				file = @filehandles[line['handle'].to_i]

				length = line['end'].to_i - line['start'].to_i
				send_command('1', 'file send;handle='+line['handle'], length)
				file.seek(line['start'].to_i)
				data = file.read(length)
				#puts data.length, length
				#puts data.dump
				@connection.send(data)
				return
			end
			
			if event.command['command'] == 'presence list'
				if line['network'] and line['presence']
					network = createnetworkifnot(line['network'], line['presence'])
					network.set_username(line['name'] ) if line['name']
					send_command('channels', "channel list")
				end
				
			elsif event.command['command'] == 'channel list'
				if line['network'] and line['presence'] and line['name']
					if @serverlist[line['network'], line['presence']] and !@serverlist[line['network'], line['presence']][line['name']]
						channel = @serverlist[line['network'], line['presence']].add(line['name'])
						#puts 'adding channel '+line['name']+' to server '+line['network']
						if line['topic']
							channel.topic = line['topic']
						end
						switchchannel(channel)
						puts 'getting channel info'
						send_command('listchan-'+line['network']+line['name'], "channel names;network="+line['network']+";channel="+line['name']+";presence="+line['presence'])
						send_command('events-'+line['network']+line['name'], "event get;end=*;limit=500;filter=(channel="+line['name']+")")
					else
						puts 'channel call for existing network, ignoring '+line['network']+' '+line['presence']+' '+line['name']
						return
					end
				end
				
			end
			
			if line['network'] and line['presence']
				if !@serverlist[line['network'], line['presence']]
					puts 'Error, non existant network event caught, ignoring'
				else
					network = @serverlist[line['network'], line['presence']]
				end
				
				if line['channel']
					if !@serverlist[line['network'], line['presence']][line['channel']]
						puts 'Error, non existant channel event caught, ignoring '+line['network']+' '+line['presence']+' '+line['channel']+' '+event.origcommand
						return
					else
						channel = @serverlist[line['network'], line['presence']][line['channel']]
					end
				end
			
				if event.command['command'] == 'channel names'
					if line['network'] and line['presence'] and line['channel'] and line['name']
						network.users.create(line['name'])
						channel.adduser(line['name'], true)
						@window.updateusercount
					end
					
				elsif event.command['command'] == 'event get'
					if line['event'] == 'msg'
						if line['address'] and network.users[line['name']] and network.users[line['name']].hostname == 'hostname'
							network.users[line['name']].hostname = line['address']
						end
							
						if line['own']
							line['nick'] = line['presence']
							channel.send_event(line, USERMESSAGE, BUFFER_START)
						else
							channel.send_event(line, MESSAGE, BUFFER_START)
						end
						
					elsif line['event'] == 'channel_changed'
						if line['topic'] and line['topic_set_by']
							pattern = "Topic set to %6"+line['topic']+ "%6 by %6"+line['topic_set_by']+'%6'
						elsif line['topic']
							pattern ="Topic for %6"+line['channel']+ "%6 is %6"+line['topic']+'%6'
						elsif line['topic_set_by']
							pattern = "Topic for %6"+line['channel']+ "%6 set by %6"+line['topic_set_by']+'%6 at %6'+line['topic_timestamp']+'%6'
						end
						line['msg'] = pattern
						
						if line['topic']
							channel.topic = line['topic']
						end
						
						if pattern
							channel.send_event(line, NOTICE, BUFFER_START)
						end
						
						#@window.topic.text = line['topic'] if line['topic']
						@window.updatetopic
						
					elsif line['event'] == 'channel_presence_removed'
						return if line['deinit']
						
						if line['name'] == network.username
							channel.send_event(line, USERPART, BUFFER_START)
						else
							channel.send_event(line, PART, BUFFER_START)
						end
					
					elsif line['event'] == 'channel_part'
						channel.send_event(line, USERPART, BUFFER_START)
						channel.disconnect
						
					elsif line['event'] == 'channel_join'
						channel.reconnect
						channel.send_event(line, USERJOIN, BUFFER_START)
						
						
					elsif line['event'] == 'channel_presence_added'
						return if line['init']
						
						if line['name'] == network.username
							channel.send_event(line, USERJOIN, BUFFER_START)
						else
							channel.send_event(line, JOIN, BUFFER_START)
						end
					end
				elsif line['status'] == '+'
					#puts 'done'
					return
				else
					#line.each{ |key, value|
				#		puts key+'='+value+"\n"
				#		}
				#	puts "\n"
				end
			end
#			@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
			
		end
		#@events.delete(event.name)
	end
	
	def parse_line(line)
		
		#create the network and channel only if explicitly done here
		if line['type'] == 'gateway_connecting'
			if !@serverlist[line['network'], line['presence']]
				switchchannel(@serverlist.add(line['network'], line['presence']))
			elsif !@serverlist[line['network'], line['presence']].connected
				puts 'server exists but is not connected, reconnecting'
				@serverlist[line['network'], line['presence']].reconnect
			else
				puts 'request to create already existing channel, ignoring'
				return
			end
		elsif line['type'] == 'channel_init'
			if !@serverlist[line['network'], line['presence']]
				puts 'Error, non existant channel init event caught, ignoring'
				return
			elsif @serverlist[line['network'], line['presence']][line['channel']] and ! @serverlist[line['network'], line['presence']][line['channel']].connected
				puts 'channel exists, but is not connected, reconnecting'
				@serverlist[line['network'], line['presence']][line['channel']].reconnect
				
			elsif @serverlist[line['network'], line['presence']][line['channel']]
				puts 'request to create already existing channel, ignoring'
				return
			else
				switchchannel(@serverlist[line['network'], line['presence']].add(line['channel']))
			end
		end
		
		#trap for events that refer to a channel that does not exist
		if line['network'] and line['presence']
			if !@serverlist[line['network'], line['presence']]
				puts 'Error, non existant network event caught, ignoring'
				return
			else
				network = @serverlist[line['network'], line['presence']]
			end
			
			if line['channel']
				if !@serverlist[line['network'], line['presence']][line['channel']]
					puts 'Error, non existant channel event caught, ignoring '+line['network']+' '+line['presence']+' '+line['channel']
					return
				else
					channel = @serverlist[line['network'], line['presence']][line['channel']]
				end
			end
				
			#ignore the spamular stuff here before we get any further
			if line['type'] == 'irc_event' or line['type'] == 'client_command_reply'
				return
			elsif line['type'] == 'notice'
				network.send_event(line, NOTICE)
				
			elsif line['type'] == 'channel_presence_removed'
				if ! line['deinit']
					if line['name'] == network.username
						channel.send_event(line, USERPART)
					else
						channel.send_event(line, PART)
					end
					channel.deluser(line['name'])
					@window.updateusercount
				else
					channel.deluser(line['name'], true)
				end
				
			elsif line['type'] == 'channel_part'
				channel.send_event(line, USERPART)
				channel.disconnect
				
			elsif line['type'] == 'channel_join'
				channel.reconnect
				channel.send_event(line, USERJOIN)
				
			elsif line['type'] == 'channel_presence_added'
						
				if !line['init']
					channel.adduser(line['name'])
					if line['name'] == network.username
						channel.send_event(line, USERJOIN)
					else
						channel.send_event(line, JOIN)
						@window.updateusercount
					end
				elsif
					channel.adduser(line['name'], false)
				end
				
			elsif line['type'] == 'presence_changed'
				if line['new_name']
				
					if line['name'] == network.username
						network.set_username(line['new_name'])
						@window.get_username
						@window.show_username
					end
					pattern = $config['notice'].deep_clone
					
					user = network.users[line['name']]
					
					if user
						user.rename(line['new_name'])
					end
					
					if line['new_name'] == network.username
						pattern = 'You are now known as '+line['new_name']
					elsif line['name'] != line['new_name']
						pattern= line['name']+' is now known as '+line['new_name']
					else
						pattern = nil
					end
					
					line['msg'] = pattern
					
					if pattern
						network.channels.each{ |c|
							if c.users[line['new_name']]
								#puts c.users[line['new_name']]
								c.drawusers
								c.send_event(line, NOTICE)
							end
						}
					end
				end
	
				if line['address']
					if user = network.users[line['name']]
						user.hostname = line['address']
					end
				end
				
			elsif line['type'] == 'presence_init'
				#puts 'presence init '+line['name']
				network.users.create(line['name'])
				
			elsif line['type'] == 'presence_deinit'
				#puts 'presence deinit'
				network.users.remove(line['name'])
				
			#~ elsif line['type'] == 'presence_changed'
				#~ if network.users[line['name']]
					#~ network.users[line['name']].hostname = line['address']
				#~ end	
				
			elsif line['type'] == 'msg'
				return if !line['channel']
				
				if line['address'] and network.users[line['name']] and network.users[line['name']].hostname == 'hostname'
					network.users[line['name']].hostname = line['address']
				end
				
				if line['own']
					channel.send_event(line, USERMESSAGE)
				else
					channel.send_event(line, MESSAGE)
				end
				
			elsif line['type'] == 'gateway_connecting'
				msg = "Connecting to "+line['ip']
				msg += ":"+line['port'] if line['port']
				line['msg'] = msg
				network.send_event(line, NOTICE)
				
			elsif line['type'] == 'gateway_connected'
				msg = "Connected to "+line['ip']
				msg += ":"+line['port'] if line['port']
				line['msg'] = msg
				network.send_event(line, NOTICE)
				
			elsif line['type'] == 'gateway_connect_failed'
				err = "Connection to "+line['ip']+':'+line['port']+" failed : "+line['error']
				line['err'] = err
				network.send_event(line, ERROR)
				
			elsif line['type'] == 'gwconn_changed' or line['type'] == 'gateway_changed'
				msg = line['presence']+" sets mode +"+line['irc_mode']+" "+line['presence']
				line['msg'] = msg
				network.send_event(line, NOTICE)
			
			elsif line['type'] == 'gateway_motd'
				line['msg'] = line['data']
				network.send_event(line, NOTICE)
			
			elsif line['type'] == 'channel_changed'
				if line['initial_presences_added']
					puts 'initial presences added'
					@window.updateusercount
				elsif line['topic'] and line['topic_set_by']
					#pattern = "Topic set to %6"+line['topic']+ "%6 by %6"+line['topic_set_by']+'%6'
					pattern = "%6"+line['topic_set_by']+'%6 has changed the topic to: %6'+line['topic']+'%6'
				elsif line['topic']
					pattern ="Topic for %6"+line['channel']+ "%6 is %6"+line['topic']+'%6'
				elsif line['topic_set_by']
					pattern = "Topic for %6"+line['channel']+ "%6 set by %6"+line['topic_set_by']+'%6 at %6'+line['topic_timestamp']+'%6'
				end
				line['msg'] = pattern
				
				if line['topic']
					channel.topic = line['topic']
					@window.updatetopic
				end
				
				if pattern
					channel.send_event(line, NOTICE)
				end
				
				#@topic.text = line['topic'] if line['topic']
				
			else
				puts line['type']
			end
		end
	end
	
	def whois(event)
		
		network = @serverlist[event.command['network'], event.command['presence']]
		
		event.lines.each do |line|
		
			if line['address'] and line['real_name']
				msg = '('+line['address']+') : '+line['real_name']
			elsif line['address']
				address = line['address']
				next
			elsif line['real_name'] and address
				msg = address+' : '+line['real_name']
			elsif line['server_address'] and line['server_name']
				msg = line['server_address']+' : '+line['server_name']
			elsif line['idle'] and line['login_time']
				idletime = duration(line['idle'].to_i)
				#puts idletime
				logintime = duration(Time.at(line['time'].to_i) - Time.at(line['login_time'].to_i))
				#puts logintime
				msg = 'Idle: '+idletime+' -- Logged on: '+Time.at(line['login_time'].to_i).strftime('%c')+' ('+logintime+')'
			elsif line['channels']
				msg = line['channels']
			elsif line['extra']
				msg = line['extra']
			elsif line['status'] == '+'
				msg = 'End of /whois'
				line['name'] = event.command['name']
			else
				next
			end
			
			pattern = $config['whois'].deep_clone
			pattern['%m'] = msg if msg
			pattern['%n'] = line['name'] if line['name']
			line['msg'] = pattern
			network.send_event(line, NOTICE)
			time = line['time']
		end
	end
	
	def createnetworkifnot(network, presence)
		if ! @serverlist[network, presence]
			switchchannel(@serverlist.add(network, presence))
		end
		
		return @serverlist[network, presence]
	end
	
	def createchannelifnot(network, channel)
		if network and ! network[channel]
			switchchannel(network.add(channel))
		elsif ! network
			puts "ERROR: invalid network!"
			return nil
		end
		
		return network[channel]
	end
	
	def quit
		$config.send_config
		send_command('quit', 'quit')
		@connection.close if @connection
		puts 'bye byeeeeee...'
		Gtk.main_quit
		exit
	end
end
begin
	$config = Configuration.new
	$main = Main.new
	$main.start
rescue Interrupt
	puts 'got keyboard interrupt'
	$main.window.quit
	$main.quit
end

