
#define some status constants
INACTIVE = 0
AWAYUSER = 1
NEWDATA = 2
NEWMSG = 3
ACTIVE = 4

BUFFER_START = 0
BUFFER_END = 1

MESSAGE = 0
USERMESSAGE = 1
JOIN = 2
USERJOIN = 3
PART = 4
USERPART = 5
ERROR = 6
NOTICE = 7
	

module Stuff
	#nice little mixin for common methods
	attr_reader :endmark
	#spaceship operator
	def <=>(object)
		length = @name.length
		retval =-1
		if object.name.length < @name.length
			length = object.name.length
			retval = 1
		end
		
		for i in 0...(length)
			if @name[i] > object.name[i]
				return 1
			elsif @name[i] < object.name[i]
				return -1
			end
		end
		return retval
	end
	
	def activate
		@button.active=true
		@status = ACTIVE
		recolor
		return @buffer
	end
	
	def deactivate
		@button.active=false
		@status = INACTIVE
		recolor
	end
	
	def setstatus(status)
		if(status > @status)
			@status = status
			#puts "status set to "+status.to_s
			recolor
		end
	end
	
	def disconnect
		@button.label = '('+@name+')'
		#line = {}
		#line['err'] = 'Disconnected'
		#line['time'] = Time.new.to_i
		#send_event(line, ERROR)
		@connected = false
		#puts 'disconnecting ' +@name
	end
	
	def reconnect
		@button.label = @name
		@connected = true
		#line = {}
		#line['msg'] = 'Reconnected'
		#line['time'] = Time.new.to_i
		#send_event(line, NOTICE)
		#puts 'disconnecting ' +@name
	end
	
	#set the button color
	def recolor
		label = @button.child
		label.modify_fg(Gtk::STATE_NORMAL, @config.getstatuscolor(@status))
		#puts 'recolored '+@name+' to '+@status.to_s
	end
	
	def send_event(line, type, insert_location=BUFFER_END)
		return if !@connected
		
		if insert_location == BUFFER_END
			insert = @buffer.end_iter
		elsif insert_location == BUFFER_START
			insert = @buffer.start_iter
		end
		
		if @config.usetimestamp
			pattern = Time.at(line['time'].to_i).strftime(@config.timestamp)
		else
			pattern = ''
		end
		
		if type == MESSAGE
			@status = NEWMSG
			#line.each {|key, value| print key, " is ", value, "\n" }
			#puts "\n"
			pattern += @config.message.deep_clone
			pattern['%u'] = line['nick']
			pattern['%m'] = line['msg']
			
			
		elsif type == USERMESSAGE
			@status = NEWMSG
			pattern += @config.usermessage.deep_clone
			#~ if line['nick']
				#~ pattern['%u'] = line['nick']
			#~ else
				#~ pattern['%u'] = line['presence']
			#~ end
			#puts @username, @server.username
			pattern['%u'] = @username if @username
			pattern['%m'] = line['msg']
			
			
		elsif type == JOIN
			@status = NEWDATA
			pattern += @config.join.deep_clone
			pattern['%u'] = line['name']
			pattern['%c'] = line['channel']
			if user = @users[line['name']] and user.hostname
				pattern['%h'] = user.hostname
			elsif line['address']
				pattern['%h'] = line['address']
			end
			
			
		elsif type == USERJOIN
			@status = NEWDATA
			pattern += @config.userjoin.deep_clone
			pattern['%c'] = line['channel']
			
		elsif type == PART
			@status = NEWDATA
			pattern += @config.part.deep_clone
			pattern['%u'] = line['name']
			pattern['%r'] = line['reason'] if line['reason']
			pattern['%c'] = line['channel']
			if user = @users[line['name']] and user.hostname
				pattern['%h'] = user.hostname
			elsif line['address']
				pattern['%h'] = line['address']
			end
			
		elsif type == USERPART
			@status = NEWDATA
			pattern += @config.userpart.deep_clone
			pattern['%c'] = line['channel']
			
		elsif type == ERROR
			@status = NEWDATA
			pattern += @config.error.deep_clone
			pattern['%m'] = line['err']
			
		elsif type == NOTICE
			@status = NEWDATA
			pattern += @config.notice.deep_clone
			pattern['%m'] = line['msg']
			
		end
		
		if pattern.length > 0
			#puts pattern
			recolor
			if insert_location == BUFFER_START
				pattern += "\n"
			elsif insert.offset != 0
				pattern = "\n"+pattern
			end
			colortext(pattern, insert)
		end
		
		@newlineend = @buffer.end_iter
		@endmark = @buffer.create_mark('end', @buffer.end_iter, false)
			
	end
	
	#add some text to the message buffer
	#def addtext(string)
	#	@status = NEWDATA
	#	recolor
	#	@newlinestart = @buffer.end_iter
	#	#ensure we don't have a new line at the beginning of the buffer
	#	if(@newlinestart.offset > 0)
	#		sendtobuffer("\n", nil)
	#	end
	#	colortext(string)
	#	@newlineend = @buffer.end_iter
	#	@endmark = @buffer.create_mark('end', @buffer.end_iter, false)
	#end
	
	#add a command to the buffer
	def addcommand(string)
		return if string.length == 0
		@commandbuffer.push(string)
		while @commandbuffer.length > @config.commandbuffersize
			@commandbuffer.delete_at(0)
		end
		@commandindex = @commandbuffer.length
	end
	
	#get the last command in the buffer
	def getlastcommand
		@commandindex -=1 if @commandindex != 0
		return @commandbuffer[@commandindex]
	end
	
	#get the next command in the buffer
	def getnextcommand
		@commandindex +=1
		 if @commandindex > @commandbuffer.length-1
			return ''
		else
			return @commandbuffer[@commandindex]
		end
	end
	
	#parse the colors in the text
	def colortext(string, insert, origcolor = nil)
		re = /((%\d).+?\2)/
		md = re.match(string)
		i = 0
		while md.class == MatchData
			insert = sendtobuffer(md.pre_match, insert, origcolor) if !md.pre_match.empty?
			color = md[2].gsub!('%', 'color')
			colorid = md[2].gsub!('%', '')
			text = md[0].gsub('%'+colorid, '')
			#pass the text back to the function to look for any nested colors.
			insert = colortext(text, insert, color)
			#insert = sendtobuffer(text, insert, color)
			tail = md.post_match
			md = re.match(tail)
			i+=1
		end
		if i == 0
			insert = sendtobuffer(string, insert, origcolor)
		end
		if tail
			insert = sendtobuffer(tail, insert, origcolor)
		end
		return insert
	end
	
	#send the text to the buffer
	def sendtobuffer(string, insert, color)
		enditer = @buffer.end_iter
		if color != nil
			#puts "Colored: "+color+' '+string
			@buffer.insert(insert, string, color)
		else
			#puts "Uncolored: "+string
			@buffer.insert(insert, string)
		end
		return insert
	end
end


class User
	attr_reader :hostname, :name, :lastspoke
	attr_writer :hostname, :lastspoke
	def initialize(name)
		@hostname = nil
		@name = name
		@lastspoke = Time.new
	end
	
	def rename(name)
		@name = name
	end
	
	def <=>(object)
		a = @name.downcase
		b = object.name.downcase
		
		return a <=> b
		#~ length = @name.length
		#~ retval =-1
		#~ if object.name.length < @name.length
			#~ length = object.name.length
			#~ retval = 1
		#~ end
		
		#~ for i in 0...(length)
			#~ if @name[i] > object.name[i]
				#~ #puts @name+' > '+object.name
				#~ return 1
			#~ elsif @name[i] < object.name[i]
				#~ #puts @name+' < '+object.name
				#~ return -1
			#~ end
		#~ end
		#~ return retval
	end
	
	def comparetostring(string)
	
		a = @name.downcase
		b = string.downcase
		
		return a <=> b
		#~ orig = @name.deep_clone
		
		#~ if string == orig
			#~ return 0
		#~ end
		
		#~ length = orig.length
		#~ retval =-1
		#~ if string.length < orig.length
			#~ length = string.length
			#~ retval = 1
		#~ end
		
		#~ for i in 0...(length)
			#~ if orig[i] > string[i]
				#~ #puts @name+' > '+object.name
				#~ return 1
			#~ elsif orig[i] < string[i]
				#~ #puts @name+' < '+object.name
				#~ return -1
			#~ end
		#~ end
		#~ return retval
	end
	
end

class UserList
	attr_reader :users
	def initialize
		@users = []
	end
	
	def create(name)
		return if self[name]
		new = User.new(name)
		@users.push(new)
		@users.sort!
		#puts 'creating user: ' +name
		#puts @users.length
		return new
	end
	
	def add(user)
		@users.push(user)
		@users.sort!
	end
	def remove(name)
		i = 0
		@users.each{ |user|
			if user.name == name
				#puts @users.length.to_s
				@users.delete_at(i)
				#puts 'removed at ' +i.to_s
				#puts @users.length.to_s
				@users.sort!
				return
			end
			i += 1
		}
	end
	
	def[](name)
		result = nil
		@users.each{ |user|
			if user.name == name
				#puts 'matched ' +name
				result = user
			end
		}
		return result
	end
	
	def sort
		@users.sort!
	end
	
	def length
		return @users.length
	end
end

class ServerList
	include Stuff
	attr_reader :servers, :box, :buffer, :button, :name, :parent, :config, :username, :connected
	def initialize(parent)
		@username = ''
		@parent = parent
		@servers = Array.new
		@box = Gtk::HBox.new
		@box.show
		@config = @parent.config
		@buffer = Gtk::TextBuffer.new
		@buffer.create_tag('color1', {'foreground_gdk'=>@config.color1})
		@buffer.create_tag('color2', {'foreground_gdk'=>@config.color2})
		@buffer.create_tag('color3', {'foreground_gdk'=>@config.color3})
		@buffer.create_tag('color4', {'foreground_gdk'=>@config.color4})
		@buffer.create_tag('color5', {'foreground_gdk'=>@config.color5})
		@buffer.create_tag('color6', {'foreground_gdk'=>@config.color6})
		@buffer.create_tag('standard', {'foreground_gdk'=>@config.standard})
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@button = Gtk::ToggleButton.new('servers')
		@name = 'servers'
		@button.show
		@button.active = false
		@button.setchannel(self)
		@button.signal_connect('clicked')do |w|
			@parent.switchchannel(w.channel)
			#puts 'switched'
		end
		box.pack_start(@button)
		@status = INACTIVE
		@connected = true
	end
	
	def add(name, presence)
		return if !presence or !name
		x = name2index(name, presence)
		if x  != nil and x.connected
			puts "You are already connected to " + name + "for presence "+ presence
			return
		#elsif x!= nil and ! x.connected
		#	x.connect
		#	return x
		else
			newserver = Server.new(name, presence, self)
			@servers.push(newserver)
			@servers = @servers.sort
			insertintobox(newserver)
			return newserver
		end
	end
	
	def insertintobox(newserver)
		#insert the widget
		@box.pack_start(newserver.box, true, true)
		for i in 0...(@servers.length)
			#puts @servers[i].name
			if @servers[i] == newserver
				if i !=0 and i == @servers.length-1
					seperator = Gtk::VSeparator.new
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					@box.reorder_child(seperator, @servers.length*2)
					@box.reorder_child(newserver.box, @servers.length*2)
					#puts 'a '+ @servers.length.to_s
				elsif i > 0
					seperator = Gtk::VSeparator.new
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					@box.reorder_child(seperator, (i*2)+1)
					@box.reorder_child(newserver.box, (i*2)+2)
					#puts 'b'+i.to_s
				elsif i == 0 and @servers.length > 1
					seperator = Gtk::VSeparator.new
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					
					@box.reorder_child(seperator, i+2)
					@box.reorder_child(newserver.box, i+2)
					#puts 'c'
				else
					#puts 'd'
					seperator = Gtk::VSeparator.new
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					@box.reorder_child(seperator, @servers.length+1)
					@box.reorder_child(newserver.box, @servers.length+1)
				end
			end
		end
	end
	
	def [](key, presence)
		if key.kind_of?(Integer)
			return @servers[key]
		else
			return name2index(key, presence)
		end
	end
	
	def name2index(name, presence)
		for i in 0...@servers.length
			return @servers[i] if( name == @servers[i].name and presence == @servers[i].presence)
		end
		return nil
	end
end

class Server
	include Stuff
	attr_reader :name, :channels, :buffer, :button, :box, :parent, :config, :username, :presence, :connected, :users
	#attr_writer :username, :presence
	def initialize(name, presence, parent)
		@presence = presence
		#puts @presence
		@username = @presence.deep_clone
		@parent = parent
		@name = name
		@channels = Array.new
		@config = getparentwindow.config
		@buffer = Gtk::TextBuffer.new
		@users = UserList.new
		@buffer.create_tag('color1', {'foreground_gdk'=>@config.color1})
		@buffer.create_tag('color2', {'foreground_gdk'=>@config.color2})
		@buffer.create_tag('color3', {'foreground_gdk'=>@config.color3})
		@buffer.create_tag('color4', {'foreground_gdk'=>@config.color4})
		@buffer.create_tag('color5', {'foreground_gdk'=>@config.color5})
		@buffer.create_tag('color6', {'foreground_gdk'=>@config.color6})
		@buffer.create_tag('standard', {'foreground_gdk'=>@config.standard})
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@button = Gtk::ToggleButton.new(@name)
		@button.setchannel(self)
		@button.signal_connect('clicked')do |w|
			getparentwindow.switchchannel(w.channel)
			#puts 'switched '+ @name+" "+@presence
		end
		@button.active = false
		@box = Gtk::HBox.new
		@box.pack_start(@button, false, false)
		@box.show
		@status = INACTIVE
		if(@config.serverbuttons)
			@button.show
		end
		@connected = true
	end
	
	def add(name)
		if name2index(name) != nil
			puts 'You are already connected to #'+name+" on this server"
			return
		end
		newchannel = Channel.new(name, self)
		@channels.push(newchannel)
		@channels = @channels.sort
		insertintobox(newchannel)
		return newchannel
	end
	
	def insertintobox(newchannel)
		#insert the widget
		@box.pack_start(newchannel.button, true, true)
		for i in 0...(@channels.length)
			if @channels[i] == newchannel
				@box.reorder_child(newchannel.button, i+1)
				return
			end
		end
	end
	
	def redrawbox
		for i in 0...(@channels.length)
			@box.remove(@channels[i].button)
		end
		for i in 0...(@channels.length)
			@box.pack_start(@channels[i].button)
		end
	end
	
	def [](key)
		if key.kind_of?(Integer)
			return @channels[key]
		else
			return name2index(key)
		end
	end
	
	def name2index(name)
		for i in 0...@channels.length
			return @channels[i] if name == @channels[i].name
		end
		return nil
	end
	
	def getparentwindow
		return @parent.parent
	end
	
	def set_username(name)
		@username = name
	end
	
end

class Channel
	include Stuff
	attr_reader :name, :buffer, :button, :server, :config, :userlist, :renderer, :column, :connected, :users, :topic, :username
	attr_writer :topic
	def initialize(name, server)
		@server = server
		@name = name
		puts @server.username
		@username = @server.username
		@config = getparentwindow.config
		@buffer = Gtk::TextBuffer.new
		@userlist = Gtk::ListStore.new(String)
		@renderer = Gtk::CellRendererText.new
		@column = Gtk::TreeViewColumn.new("Users", @renderer)
		@column.add_attribute(@renderer, "text",  0)
		@userlist.clear
		@buffer.create_tag('color1', {'foreground_gdk'=>@config.color1})
		@buffer.create_tag('color2', {'foreground_gdk'=>@config.color2})
		@buffer.create_tag('color3', {'foreground_gdk'=>@config.color3})
		@buffer.create_tag('color4', {'foreground_gdk'=>@config.color4})
		@buffer.create_tag('color5', {'foreground_gdk'=>@config.color5})
		@buffer.create_tag('color6', {'foreground_gdk'=>@config.color6})
		@buffer.create_tag('standard', {'foreground_gdk'=>@config.standard})
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@status = INACTIVE
		@topic = ''
		@button = Gtk::ToggleButton.new(name)
		@button.setchannel(self)
		@button.signal_connect('clicked')do |w|
			getparentwindow.switchchannel(w.channel)
			#puts 'switched '+ @name
		end
		@button.label= @name
		@button.active = false
		@button.show
		@users = UserList.new
		@connected = true
		
		@useriters = []
	end
	
	def add(name)
		@server.add(name)
	end
	
	def getparentwindow
		return @server.parent.parent
	end
	
	def adduser(name, init = false)
		if @server.users[name]
			if ! @users[name]
				@users.add(@server.users[name])
				@users.sort
				if !init
					#puts 'syncing list'
					drawusers
				end
			#else
				#puts name+' already exists in userlist'
			end
			#iter = @userlist.append
			#@users[name] = iter
			#iter[0] = name
		else
			puts 'Unknown user '+name
		end
	end
	
	def drawusers
		#I *really* should just sync the list
		#@userlist.clear
		#@users.sort
		
		if @useriters.length == 0
			@users.users.each{ |user|
				iter = @userlist.append
				iter[0] = user.name
				@useriters .push(iter)
			}
		else
			i = 0
			@users.users.each do |user|
				if !@useriters[i]
					iter = @userlist.append
					iter[0] = user.name
					@useriters .push(iter)
					#puts 'end of iter list'
					return
				end
				#puts i, @useriters[i][0], user.name
				res = user.comparetostring(@useriters[i][0])
				if res == 0
					#puts 'equal, continuing'
				elsif res == 1
					#puts 'removing '+@useriters[i][0]+' at '+i.to_s
					#puts @useriters[i]
					@userlist.remove(@useriters[i])
					@useriters.delete_at(i)
				elsif res == -1
					#puts 'adding '+user.name+' at '+i.to_s
					iter = @userlist.insert_before(@useriters[i])
					iter[0] = user.name
					@useriters[i] = [iter, @useriters.at(i)]
					@useriters.flatten!
					#puts @useriters[i].class, @useriters[i+1].class
					#put in the useriters at the right place somehow...
				end
				
				i += 1
			end
			while @users.length < @useriters.length
				@userlist.remove(@useriters[@useriters.length-1])
				@useriters.delete_at(@useriters.length-1)
			end
			
			#puts @users.length.to_s,  @useriters.length.to_s
		end
	end
	
	def clearusers
		@userlist.clear
	end
	
	def deluser(user, deinit = false)
		if @users[user]
			#@userlist.remove(@users[user])
			@users.remove(user)
			@users.sort
			if !deinit
				#puts 'syncing list'
				drawusers
			end
		end
	end
	
	#~ def changeuser(old, new)
		#~ if @users[old]
			#~ @users[new] = @users[old]
			#~ @users[new][0] = new
			#~ @users.delete(old)
		#~ end
	#~ end

end
		