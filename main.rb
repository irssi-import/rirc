#!/usr/bin/env ruby

require 'libglade2'
require 'socket'

begin
	require 'config'
rescue LoadError
	puts "Cannot load config.rb, please rename and edit config.rb.factory"
	exit
end

#useful for debugginga
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

$counter = 0

class Config
	attr_reader :tagtable, :color1, :color2, :color3, :color4, :color5, :color6, :timestamp, :usermessage, :action, :notice, :serverbuttons, :commandbuffersize, :error, :message, :join, :userjoin, :part, :userpart, :usetimestamp, :standard
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

class MainWindow
	attr :config
	def initialize
		@config = Config.new
		@serverlist = ServerList.new(self)
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
		@usernamebutton = @glade["username"]
		@topic = @glade["topic"]
		@messages = @glade["message_window"]
		@messageinput = @glade["message_input"]
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
		
		@path= $path
		
		@me = self

		@events = {}

		@buffer = []
		@buffer[0] = true
		@last = nil
		connect
		
	end
	
	def connect
		Thread.start{
			begin
			@client = UNIXSocket.open(@path)
			#puts $!.kind_of?
			
			
			rescue SystemCallError
				puts "Error: no irssi2 socket at "+@path
				sleep 10
				retry
			else
				puts "Connected to irssi2!"
				startlistenthread
				if @serverlist.servers.length > 0
					#~ @serverlist.servers.each{|server|
						#~ connectnetwork(server.name, server.address, server.presence
						#~ server.channels.each {|channel|
							#~ channel.disconnect
						#~ }
					#~ }
				else
					send_command('presences', 'presence list')
				end
			end
		}
	end
	
	def disconnect
		puts 'doing global disconnect'
		@serverlist.servers.each{|server|
			server.disconnect
			server.channels.each {|channel|
				channel.disconnect
			}
		}
	end
	
	def connectnetwork(name, address, presence)
		send_command('addnet', "network add:name="+name+":protocol=irc")
		send_command('addpres', "presence add:name="+presence+":network="+name)
		send_command('addhost', "gateway add:host="+address+":network="+name+":port=6667")
		send_command('connect', "presence connect:network="+name+":presence="+presence)
	end
			
	
	def startlistenthread
		@listenthread = Thread.start{
			input = ''
			while line = @client.recv(10)
				if line.length == 0
					sleep 5
				end
				input += line
				if input.count("\n") > 0
					pos = input.rindex("\n")
					Thread.start{
						string = input[0, pos]
						parse_lines(string)
					}
					input = input[pos, input.length]
				end
			end
		}
	end
	
	def createeventcatchthread(tag, command)
		if @events[tag]
			#puts 'name currently in use!'
		end
		@events[tag] = Thread.new{
			Thread.current['raw_lines'] = []
			lines = []
			temp = {}
			thiscommand = command.deep_clone
			while true
				while Thread.current['raw_lines'].length  >= 1
					temp = {}
					line = Thread.current['raw_lines'][0]
					vars = line.split(":", 3)
					temp['tag'] = vars[0]
					temp['status'] = vars[1]
					temp['command'] = thiscommand
					temp['original'] = line
					
					if !vars[2]
						lines.push(temp)
						puts'no other info'
						break
					end
					
					items = vars[2].split(':')
					
					items.each do |x|
						vals = x.split('=', 2)
						if vals[1] and vals[1] != ''
							temp[vals[0]] = vals[1].gsub('\\\\.', ':')
						elsif x.count('=') == 0
							temp[x] = true
						end
					end
					
					Thread.current['raw_lines'].delete_at(0)
					lines.push(temp)
					if temp['status'] == '+'
						break
					end
					
					if temp['status'] == '-'
						puts line+" error!"
						output = {}
						output['err'] = line
						@serverlist.send_event(output, ERROR)
						break
					end
					
				end
				
				if temp['status'] == '+'
					break
				end
				
				sleep 1
			end
			
			@events.delete(lines[0]['tag'])
			#puts "removed listener thread for "+tag
			
			lines.each{|l| parse_command_output(l)}
			}
		#puts "created listener thread for "+tag
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

		if message =~ /^\/([a-z]+)[\s]*(.*)$/
			command = $1
			arguments = $2
			if command == 'join' and network
				send_command('join', "channel join:network="+network+":channel="+arguments)
			elsif command == 'server' and  arguments  =~ /^([a-zA-Z0-9_]+):([a-zA-Z0-9_.]+)$/
				#puts $1, $2, presence
				connectnetwork($1, $2, presence)
			elsif command == 'part'
				arguments = arguments.split(' ')
				if arguments[0]
					send_command('part', "channel part:network="+network+":presence="+$presence+":channel="+arguments[0])
				else
					line = {}
					line['err'] = 'Part requires a channel argument'
					line['time'] = Time.new.to_i
					@currentchan.send_event(line, ERROR)
				end
			elsif command == 'quit'
				send_command('quit', 'quit')
				Gtk.main_quit
			elsif command == 'shutdown'
				send_command('shutdown', 'shutdown')
				Gtk.main_quit
			elsif command == 'ruby'
				puts 'possibly evil ruby code inputted, blindly executing'
				eval(arguments)
			elsif command == 'raw'
				puts 'sending '+arguments
				output = {}
				output['msg'] = 'Sent raw command "'+arguments+'" to irssi2 directly'
				@serverlist.send_event(output, NOTICE)
				send_command('raw', arguments)
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
		return if !@client
		
		begin
		bleh = command.split(':', 2)
		createeventcatchthread(tag, bleh[0])
		@client.send(tag+':'+command+"\n", 0)
		
		rescue SystemCallError
			puts 'Broken Pipe to Irssi'
			@listenthread.kill
			@client = nil
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
				@events[$1]['raw_lines'].push(string)
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
	
	def parse_command_output(line)
		#~ line.each{ |key, value|
				#~ if value === true
					#~ value = 'true'
				#~ end
				#~ puts key+'='+value+"\n"
				#~ }
			#~ puts "\n"
			
		if line['tag'] == 'raw'
			output = {}
			output['msg'] =  line['original']
			@serverlist.send_event(output, NOTICE)
			return
		end
		
		if line['command'] == 'presence list'
			if line['network'] and line['presence']
				createnetworkifnot(line['network'], line['presence'])
				send_command('channels', "channel list")
			end
			
		elsif line['command'] == 'channel list'
			if line['network'] and line['presence'] and line['name']
				if @serverlist[line['network'], line['presence']] and !@serverlist[line['network'], line['presence']][line['name']]
					channel = @serverlist[line['network'], line['presence']].add(line['name'])
					if line['topic']
						channel.topic = line['topic']
					end
					switchchannel(channel)
					send_command('listchan'+line['name'], "channel names:network="+line['network']+":channel="+line['name']+":presence="+line['presence'])
					send_command('events'+line['name'], "event get:end=*:limit=100:filter=channel=="+line['name'])
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
		
			if line['command'] == 'channel names'
				if line['network'] and line['presence'] and line['channel'] and line['name']
					#@serverlist[line['network'], line['presence']][line['channel']].adduser(line['name'])
					network.users.create(line['name'])
					channel.adduser(line['name'])
				end
			elsif line['command'] == 'event get'
				if line['msg']
					if line['address'] and network.users[line['name']] and network.users[line['name']].hostname == 'hostname'
						network.users[line['name']].hostname = line['address']
					end
						
					if line['own']
						line['nick'] = line['presence']
						channel.send_event(line, USERMESSAGE, BUFFER_START)
					else
						channel.send_event(line, MESSAGE, BUFFER_START)
					end
					
				elsif line['channel_changed']
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
					
				elsif line['channel_presence_removed']
					return if line['deinit']
					
					if line['name'] == network.username
						channel.send_event(line, USERPART, BUFFER_START)
					else
						channel.send_event(line, PART, BUFFER_START)
					end
					
				elsif line['channel_presence_added']
					return if line['init']
					
					if line['name'] == network.username
						channel.send_event(line, USERJOIN, BUFFER_START)
					else
						channel.send_event(line, JOIN, BUFFER_START)
					end
				end
			elsif line['status'] == '+'
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
				end
				
				channel.deluser(line['name'])
				
			elsif line['type'] == 'channel_part'
				channel.send_event(line, USERPART)
				channel.disconnect
				
			elsif line['type'] == 'channel_join'
				channel.reconnect
				channel.send_event(line, USERJOIN)
				
			elsif line['type'] == 'channel_presence_added'
				channel.adduser(line['name'])
				
				if !line['init']
					if line['name'] == network.username
						channel.send_event(line, USERJOIN)
					else
						channel.send_event(line, JOIN)
					end
				end
				
			elsif line['type'] == 'presence_changed'
				if line['new_name']
					pattern = @config.notice.deep_clone
					
					user = network.users[line['name']]
					
					if user
						#puts 'matched uswer'+user.name
						user.rename(line['new_name'])
						#puts 'matched uswer'+user.name
						#puts network.users[line['new_name']]
					end
					
					if line['name'] == line['presence']
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
				#puts 'presence init'
				network.users.create(line['name'])
				
			elsif line['type'] == 'presence_deinit'
				#puts 'presence deinit'
				network.users.remove(line['name'])
				
			elsif line['type'] == 'presence_changed'
				if network.users[line['name']]
					network.users[line['name']].hostname = line['address']
				end	
				
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
		@usernamebutton.label = @currentchan.username if @currentchan.username
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
		else
			@mainbox.remove(@panel)
			@panel.remove(@messagebox)
			@mainbox.pack_start(@messagebox)
			@messageinput.grab_focus
			@topic.hide
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
		Gtk.main_quit
	end
end

Gtk.init
MainWindow.new
Gtk.main

