#!/usr/bin/env ruby

require 'libglade2'
require 'socket'
require 'rbconfig'
include Config
puts CONFIG['target']

#$:.push('./lib')

begin
	require 'config'
rescue LoadError
	puts "Cannot load config.rb, please rename and edit config.rb.factory"
	exit
end

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
	
	#return {'seconds'=>secs, 'minutes'=>mins, 'hours'=>hours, 'days'=>days}
end

	

$counter = 0

class Configuration
	attr_reader :tagtable, :color1, :color2, :color3, :color4, :color5, :color6, :timestamp, :usermessage, :action, :notice, :serverbuttons, :commandbuffersize, :error, :message, :join, :userjoin, :part, :userpart, :usetimestamp, :standard, :whois
	def initialize
		@color1 = Gdk::Color.new(65535, 0, 0)
		@color2 = Gdk::Color.new(0, 65535, 0)
		@color3 = Gdk::Color.new(0, 0, 65535)
		@color4 = Gdk::Color.new(65535, 65535, 0)
		@color5 = Gdk::Color.new(65535, 0, 65535)
		@color6 = Gdk::Color.new(0, 65535, 65535)
		
		@standard = Gdk::Color.new(0, 0, 0)
		
		@statuscolors = [Gdk::Color.new(0, 0, 0), Gdk::Color.new(1000, 1000, 1000), Gdk::Color.new(45535, 1000, 1000), Gdk::Color.new(65535, 0, 0), Gdk::Color.new(0, 0, 65535)]
		
		@usetimestamp = true
		@timestamp = "[%H:%M]"
		@message = "%3<%3%u%3>%3 %m"
		@usermessage = "%5<%5%u%5>%5 %m"
		@action = "%1*%1%u %m"
		@notice = "-%2--%2 %m"
		@error = "%1***%1 %m"
		@join = "-%2->%2 %u (%2%h%2) has joined %c"
		@userjoin = "-%2->%2 You are now talking on %c"
		@part = "<%2--%2 %u (%2%h%2) has left %c (%r)"
		@userpart = "<%2--%2 You have left %c"
		@whois = "%3[%3%n%3]%3 %m"
		
		@serverbuttons = true
		
		@commandbuffersize = 10
		
		@tagtable = Gtk::TextTagTable.new
		@colortag1= Gtk::TextTag.new('color1')
		@tagtable.add(@colortag1)
		@colortag1.foreground_gdk=@color1
		@colortag1.background_gdk=@color1
		
	end
	
	#converts status into a color
	def getstatuscolor(status)
		return @statuscolors[status]
	end
end

#load servers.rb
require 'servers'
require 'events'
require 'connections'

class MainWindow
	attr :config
	def initialize
		@config = Configuration.new
		@serverlist = ServerList.new(self)
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
		@usernamebutton = @glade["username"]
		@topic = @glade["topic"]
		@messages = @glade["message_window"]
		@messageinput = @glade["message_input"]
		@messagescroll = @glade['message_scroll']
		@messagescroll.vadjustment.signal_connect('value-changed') do |w|
			#~ puts w.value.to_s
			#~ puts w.page_size.to_s
			#~ puts w.lower.to_s
			#~ puts w.upper.to_s
			#~ puts @messages.buffer.line_count.to_s
			
		end
		@messageinput.grab_focus
		@messageinput.signal_connect("key_press_event") do |widget, event|
			if event.keyval == Gdk::Keyval.from_name('Up')
				getlastcommand
			elsif event.keyval == Gdk::Keyval.from_name('Down')
				getnextcommand
			end
		end
		@channellist = @glade['channellist']
		@userbar = @glade['userbar']
		@userlist = @glade['userlist']
		@panel = @glade['hpaned1']
		@mainbox = @glade['mainbox']
		@messagebox = @glade['vbox2']
		@configwindow = @glade['config']
		@preferencesbar = @glade['preferencesbar']
		@channellist.pack_start(@serverlist.box, false, false)
		@currentchan = @serverlist
		drawuserlist(false)
		@messages.buffer = @serverlist.buffer
		@serverlist.button.active = true
		@connection = nil
		
		@path= $path
		
		@me = self

		@events = {}

		@buffer = []
		@buffer[0] = true
		@last = nil
		connect
		
	end
	
	def connect
		return if @connection
		Thread.start{
			begin
			if $method == 'ssh'
				@connection = SSHConnection.new($ssh_host)
				print 'this is '
				puts @connection
			elsif $method == 'unixsocket'
				@connection = UnixSockConnection.new($unixsocket_path)
			end
			
			puts "Connected to irssi2!"
			@connection.listen(self)
			
			rescue IOError
				puts $!
				sleep 5
				puts 'retrying...'
				retry
			end
			
			if @serverlist.servers.length > 0
				#~ @serverlist.servers.each{|server|
					#~ connectnetwork(server.name, server.address, server.presence
					#~ server.channels.each {|channel|
						#~ channel.disconnect
					#~ }
				#~ }
			else
				puts 'requesting presence list'
				send_command('presences', 'presence list')
			end
		}
	end
	
	def disconnect
		@connection = nil
		puts 'doing global disconnect'
		@serverlist.servers.each{|server|
			server.disconnect
			server.channels.each {|channel|
				channel.disconnect
			}
		}
		sleep 5#prevent flooding the server with reconnect requests
	end
	
	def connectnetwork(name, address, presence)
		send_command('addnet', "network add:name="+name+":protocol=irc")
		send_command('addpres', "presence add:name="+presence+":network="+name)
		send_command('addhost', "gateway add:host="+address+":network="+name+":port=6667")
		send_command('connect', "presence connect:network="+name+":presence="+presence)
	end
		
	def parse_lines(string)
		lines = string.split("\n")
		
		for i in 0...lines.length
			handle_output(lines[i])
		end
	end
  
	def message_input(widget)
		return if widget.text.length == 0
		
		@currentchan.addcommand(widget.text)
		channel = @currentchan.name
		if @currentchan.class == Channel
			network = @currentchan.server.name
			presence = @currentchan.server.presence
		elsif @currentchan.class == Server
			network = @currentchan.name
			presence = @currentchan.presence
		else
			presence = $presence
		end
		
		message = widget.text

		#if message =~ /^\/([a-z]+)[\s]*(.*)$/
		command, arguments = message.split(' ', 2)
		
		arguments = '' if ! arguments
		
		#command = foo[0]
		#arguments = foo[1]
		if command == '/join' and network
			send_command('join', "channel join:network="+network+":channel="+arguments)
		elsif command == '/server' and  arguments  =~ /^([a-zA-Z0-9_\-]+):([a-zA-Z0-9_.\-]+)$/
			#puts $1, $2, presence
			connectnetwork($1, $2, presence)
		elsif command == '/part'
			arguments = arguments.split(' ')
			if arguments[0]
				send_command('part', "channel part:network="+network+":presence="+$presence+":channel="+arguments[0])
			else
				line = {}
				line['err'] = 'Part requires a channel argument'
				line['time'] = Time.new.to_i
				@currentchan.send_event(line, ERROR)
			end
		elsif command == '/quit'
			send_command('quit', 'quit')
			Gtk.main_quit
		elsif command == '/shutdown'
			send_command('shutdown', 'shutdown')
			Gtk.main_quit
		elsif command == '/ruby'
			puts 'possibly evil ruby code inputted, blindly executing'
			eval(arguments)
		elsif command == '/raw'
			puts 'sending '+arguments
			output = {}
			output['msg'] = 'Sent raw command "'+arguments+'" to irssi2 directly'
			@serverlist.send_event(output, NOTICE)
			send_command('raw', arguments)
		elsif command == '/nick'
			name, bleh = arguments.split(' ', 2)
			send_command('nick'+name, 'presence change:network='+network+':presence='+presence+':new_name='+name)
		elsif command == '/whois'
			name, bleh = arguments.split(' ', 2)
			send_command('whois'+name, 'presence status:network='+network+':presence='+presence+':name='+name)
		elsif command == '/msg'
			arguments = arguments.split(' ', 2)
			if arguments[0] and arguments[1]
				messages = arguments[1].split("\n")
				messages.each { |message|
					send_command('msg'+rand(100).to_s, 'msg:network='+network+':target='+arguments[0]+':msg='+message+":presence="+presence)
				}
			else
				line = {}
				line['err'] = '/msg requires a username and a message'
				line['time'] = Time.new.to_i
				@currentchan.send_event(line, ERROR)
			end
		elsif network
			messages = message.split("\n")
			messages.each { |message|
				message.gsub!('\\', '\\\\\\')
				message.gsub!(':', '\\.')
				send_command('message'+rand(100).to_s, 'msg:network='+network+':channel='+channel+':msg='+message+":presence="+presence)
				line = {}
				line['nick'] = presence
				message.gsub!('\\.', ':')
				message.gsub!('\\\\', '\\')
				line['msg'] = message
				line['time'] = Time.new.to_i
				@currentchan.send_event(line, USERMESSAGE)
				@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
			}
		elsif !network
			line = {}
			line['err'] = 'Invalid server command'
			line['time'] = Time.new.to_i
			@currentchan.send_event(line, ERROR)
		end
		
		widget.text = ''
	end
	
	def set_username
	end
	
	def topic_change(widget)
		#add_message("Topic changed to: "+ widget.text, 'notice')
	end
	
	def handle_input(string)
		@client.send(string+"\n", 0)
		@messageinput.text = ""
		return
	end
	
	def send_command(tag, command)
		if !@connection
			puts 'connection not initialized'
			return
		end
		
		@events[tag] = Event.new(tag, command)
		sent = @connection.send(tag+':'+command+"\n")
		
		if !sent
			puts 'failed to send'
			@connection = nil
			disconnect
			connect
		end
	end
	
	def handle_output(string)
		return if string.length == 0
		#puts string
		line= {}
		re = /(^[^\*]+):([+\->]+)(.*)$/
		re2 = /^[*]+:([a-zA-Z_]+):(.+)$/
		
		if md = re.match(string)
			if @events[$1]
				#puts string
				#@events[$1]['raw_lines'].push(string)
				#puts @events[$1]
				event = @events[$1]
				Thread.new{event.addline(string)}
				if @events[$1].complete
					puts 'event '+$1+ ' complete'
					Thread.new{handle_event(event)}
				end
			else
				puts "Event for dead or unregistered handler recieved " + string
			end
			return
		elsif !md = re2.match(string)
			puts "Failed to match: "+string+"\n"
			return
		end
		line['type'] = $1
		
		items = $2.split(':')
		
		items.each do |x|
			vals = x.split('=', 2)
			if vals[1] and vals[1] != ''
				line[vals[0]] = vals[1].gsub('\\.', ':')
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
		
		puts 'handling '+event.name
		
		if event.command['command'] == 'presence status'
			whois(event)
			return
		end
		
		event.lines.each do |line|
		
			if event.name == 'raw'
				output = {}
				output['msg'] =  line['original']
				@serverlist.send_event(output, NOTICE)
				next
			end
			
			if line['status'] == '+'
				if event.command['command'] == 'channel names'
					puts 'end of user list'
					@serverlist[event.command['network'], event.command['presence']][event.command['channel']].drawusers
				end
			end
			
			if event.command['command'] == 'presence list'
				if line['network'] and line['presence']
					network = createnetworkifnot(line['network'], line['presence'])
					network.set_username(line['name'] ) if line['name']
					@usernamebutton.label = @currentchan.username.gsub('_', '__')
					send_command('channels', "channel list")
				end
				
			elsif event.command['command'] == 'channel list'
				if line['network'] and line['presence'] and line['name']
					if @serverlist[line['network'], line['presence']] and !@serverlist[line['network'], line['presence']][line['name']]
						channel = @serverlist[line['network'], line['presence']].add(line['name'])
						if line['topic']
							channel.topic = line['topic']
						end
						switchchannel(channel)
						send_command('listchan-'+line['network']+line['name'], "channel names:network="+line['network']+":channel="+line['name']+":presence="+line['presence'])
						send_command('events-'+line['network']+line['name'], "event get:end=*:limit=500:filter=(channel="+line['name']+")")
					else
						puts 'channel call for non existant network, ignoring'+line['network']+' '+line['presence']+' '+line['name']
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
						puts 'Error, non existant channel event caught, ignoring '+line['network']+' '+line['presence']+' '+line['channel']
						return
					else
						channel = @serverlist[line['network'], line['presence']][line['channel']]
					end
				end
			
				if event.command['command'] == 'channel names'
					if line['network'] and line['presence'] and line['channel'] and line['name']
						#@serverlist[line['network'], line['presence']][line['channel']].adduser(line['name'])
						network.users.create(line['name'])
						channel.adduser(line['name'], true)
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
						
						@topic.text = line['topic'] if line['topic']
						
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
					puts 'done'
					return
				else
					#line.each{ |key, value|
				#		puts key+'='+value+"\n"
				#		}
				#	puts "\n"
				end
			end
			@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
			
		end
		@events.delete(event.name)
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
					end
				elsif
					channel.adduser(line['name'], false)
				end
				
			elsif line['type'] == 'presence_changed'
				if line['new_name']
				
					if line['name'] == network.username
						#puts 'your nickname changed to '+line['new_name']
						network.set_username(line['new_name'])
						#puts network, network.username, @currentchan, @currentchan.username
						@usernamebutton.label = @currentchan.username.gsub('_', '__')
						#puts @usernamebutton.label
						@usernamebutton.show
					end
					pattern = @config.notice.deep_clone
					
					user = network.users[line['name']]
					
					if user
						#puts 'matched uswer'+user.name
						user.rename(line['new_name'])
						#puts 'matched uswer'+user.name
						#puts network.users[line['new_name']]
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
				msg = "Connecting to "+line['ip']+':'+line['port']
				line['msg'] = msg
				network.send_event(line, NOTICE)
				
			elsif line['type'] == 'gateway_connected'
				msg = "Connected to "+line['ip']+':'+line['port']
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
				if line['topic'] and line['topic_set_by']
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
				end
				
				if pattern
					channel.send_event(line, NOTICE)
				end
				
				@topic.text = line['topic'] if line['topic']
				
			else
				puts line['type']
			end
			@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
		end
	end
	
	def whois(event)
	
		#~ address = ''
		#~ real_name = ''
		#~ channels = ''
		#~ server_address = ''
		#~ server_name = ''
		#~ extra = ''
		#~ idle = ''
		#~ login_time = ''
		
		#~ event.lines.each do |line|
			#~ address = line['address'] if line['address']
			#~ real_name = line['real_name'] if line['real_name']
			#~ channels = line['channels'] if line['channels']
			#~ server_address = line['server_address'] if line['server_address']
			#~ server_name = line['server_name'] if line['server_name']
			#~ extra = line['extra'] if line['extra']
			#~ idle = line['idle'] if line['idle']
			#~ login_time = line['login_time'] if line['login_time']
		#~ end
		
		network = @serverlist[event.command['network'], event.command['presence']]
		#~ network.send_event('('+address+') : '+real_name, NOTICE)
		#~ network.send_event(extra, NOTICE)
		#~ network.send_event(channels, NOTICE)
		#~ network.send_event(server_name+' '+server_address, NOTICE)
		#~ network.send_event('Idle: '+idle+' Logon: '+login_time, NOTICE)
		#~ network.send_event('END of WHOIS', NOTICE)
		
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
			
			pattern = @config.whois.deep_clone
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
	

	
	def switchchannel(channel)
		#make the new channel the current one, and toggle the buttons accordingly
		return if @currentchan == channel
		@currentchan.deactivate
		@userlist.remove_column(@currentchan.column) if @currentchan.class == Channel
		@currentchan = channel
		@messages.buffer = @currentchan.activate
		@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
		@usernamebutton.label = @currentchan.username.gsub('_', '__') if @currentchan.username
		drawuserlist(@currentchan.class == Channel)
	end
	
	def drawuserlist(toggle)
		if toggle
			@mainbox.remove(@messagebox)
			@mainbox.pack_start(@panel)
			@panel.add1(@messagebox)
			@messageinput.grab_focus
			@userlist.model = @currentchan.userlist
			@userlist.append_column(@currentchan.column)
			@userlist.show_all
			@topic.show
			@topic.text =@currentchan.topic
			@usernamebutton.show
		else
			@mainbox.remove(@panel)
			@panel.remove(@messagebox)
			@mainbox.pack_start(@messagebox)
			@messageinput.grab_focus
			@topic.hide
			@topic.text = ''
			if @currentchan.class == ServerList
				@usernamebutton.hide
			else
				@usernamebutton.show
			end
		end
	end
	
	def getlastcommand
		@messageinput.text = @currentchan.getlastcommand
		@messageinput.grab_focus
	end
	
	def getnextcommand
		@messageinput.text = @currentchan.getnextcommand
		@messageinput.grab_focus
	end
	
	def on_preferences1_activate
		
		#puts 'decorated' if @configwindow.decorated?
		@cells = Gtk::CellRendererText.new
		@cells.text = "bleh"
		#puts @preferencesbar.insert_column(1, 'Preferences', @cells, {}).to_s 
		@configwindow.show_all
	end
	
	def quit
		send_command('quit', 'quit')
		@connection.close if @connection
		Gtk.main_quit
	end
end

Gtk.init
MainWindow.new
Gtk.main

