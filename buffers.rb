#define some status constants
INACTIVE = 0
NEWDATA = 1
NEWMSG = 2
ACTIVE = 3

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

class Buffer
	attr_reader :endmark, :oldendmark, :currentcommand, :buffer, :button
	attr_writer :currentcommand
	#spaceship operator
	def initialize(name)
		@buffer = Gtk::TextBuffer.new
		@buffer.create_tag('color0', {'foreground_gdk'=>$config['color0']})
		@buffer.create_tag('color1', {'foreground_gdk'=>$config['color1']})
		@buffer.create_tag('color2', {'foreground_gdk'=>$config['color2']})
		@buffer.create_tag('color3', {'foreground_gdk'=>$config['color3']})
		@buffer.create_tag('color4', {'foreground_gdk'=>$config['color4']})
		@buffer.create_tag('color5', {'foreground_gdk'=>$config['color5']})
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@button = Gtk::ToggleButton.new(name)
		@button.show
		@button.active = false
		@togglehandler = @button.signal_connect('toggled')do |w|
			switchchannel(self)
		end
		puts @togglehandler
	end
	
	def switchchannel(channel)
		#puts @button.toplevel 
		return if @button.toplevel.class != Gtk::Window
		#puts channel
		$main.window.switchchannel(channel)
	end
	
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
		@button.signal_handler_block(@togglehandler)
		@button.active=true #if !@button.active?
		@button.signal_handler_unblock(@togglehandler)
		#@button.signal_emit_stop('toggled')
		@status = ACTIVE
		recolor
		return @buffer
	end
	
	def deactivate
		@button.signal_handler_block(@togglehandler)
		@button.active=false #if @button.active?
		#@button.signal_emit_stop('toggled')
		@button.signal_handler_unblock(@togglehandler)
		@status = INACTIVE
		recolor
	end
	
	def setstatus(status)
		if(status > @status)
			@status = status
			recolor
		end
	end
	
	def disconnect
		@button.label = '('+@name+')'
	end
	
	def reconnect
		@button.label = @name
		@connected = true
	end
	
	#set the button color
	def recolor
		label = @button.child
		label.modify_fg(Gtk::STATE_NORMAL, $config.getstatuscolor(@status))
	end
	
	def send_event(line, type, insert_location=BUFFER_END)
		return if !@connected
		
		if insert_location == BUFFER_END
			insert = @buffer.end_iter
		elsif insert_location == BUFFER_START
			insert = @buffer.start_iter
		end
		
		if $config['usetimestamp']
			pattern = Time.at(line['time'].to_i).strftime($config['timestamp'])
		else
			pattern = ''
		end
		
		links = []
		users = []
		
		@oldlineend = @buffer.end_iter
		@oldendmark = @buffer.create_mark('oldend', @buffer.end_iter, false)
		
		if type == MESSAGE
			setstatus(NEWMSG)
			pattern += $config['message'].deep_clone
			if line['nick']
				pattern['%u'] = line['nick']
				users.push(line['nick'])
			end
			pattern['%m'] = line['msg'] if line['msg']
			
			
		elsif type == USERMESSAGE
			setstatus(NEWMSG)
			pattern += $config['usermessage'].deep_clone
			if username
				pattern['%u'] = username
				users.push(username)
			end
			pattern['%m'] = line['msg'] if line['msg']
			
			
		elsif type == JOIN
			setstatus(NEWDATA)
			pattern += $config['join'].deep_clone
			pattern['%u'] = line['name']
			users.push(line['name'])
			pattern['%c'] = line['channel']
			if user = @users[line['name']] and user.hostname
				pattern['%h'] = user.hostname
			elsif line['address']
				pattern['%h'] = line['address']
			end
			
			
		elsif type == USERJOIN
			setstatus(NEWDATA)
			pattern += $config['userjoin'].deep_clone
			pattern['%c'] = line['channel']
			
		elsif type == PART
			setstatus(NEWDATA)
			pattern += $config['part'].deep_clone
			pattern['%u'] = line['name']
			users.push(line['name'])
			pattern['%r'] = line['reason'] if line['reason']
			pattern['%c'] = line['channel']
			if user = @users[line['name']] and user.hostname
				pattern['%h'] = user.hostname
			elsif line['address']
				pattern['%h'] = line['address']
			end
			
		elsif type == USERPART
			setstatus(NEWDATA)
			pattern += $config['userpart'].deep_clone
			pattern['%c'] = line['channel']
			
		elsif type == ERROR
			setstatus(NEWDATA)
			pattern += $config['error'].deep_clone
			pattern['%m'] = line['err']
			
		elsif type == NOTICE
			setstatus(NEWDATA)
			pattern += $config['notice'].deep_clone
			pattern['%m'] = line['msg']
			
		end
		
		#users.push(line['name']) if line['name']
		
		if pattern.length > 0
			#puts pattern
			recolor
			if insert_location == BUFFER_START
				#puts 'at start'
				if @buffer.char_count > 0
					pattern += "\n"
				end
			elsif insert.offset != 0
				#puts 'not at start'
				pattern = "\n"+pattern
			end
			colortext(pattern, insert, users)
		end
		
		@newlineend = @buffer.end_iter
		@endmark = @buffer.create_mark('end', @buffer.end_iter, false)
		
		$main.scroll_to_end(self)
			
	end
	
	#add a command to the buffer
	def addcommand(string)
		return if string.length == 0
		@commandbuffer.push(string)
		while @commandbuffer.length > $config['commandbuffersize'].to_i
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
	def colortext(string, insert, users)
		re = /((%\d).+?\2)/
		md = re.match(string)
		
		tags = {}
		
		while md.class == MatchData
			#get the color
			color = md[2].gsub!('%', 'color')
			colorid = md[2].gsub!('%', '')
			#remove the color tags from the text
			text = md[0].gsub('%'+colorid, '')
	
			#strip the color tags for this tag from the string
			string[md[0]] = text
			
			#create a tag with a range
			start, stop = md.offset(1)
			stop -= (md[2].length)*2
			tags[Range.new(start, stop)] = color
			
			#go around again
			md = re.match(string)
		end
		
		links = []
		
		re = /(([a-zA-Z]+\:\/\/|[a-zA-Z0-9]+\.)[a-zA-Z0-9.-]+\.[a-zA-Z.]+([^\s\n\(\)\[\]\r]+|))/
		md = re.match(string)
		
		while md.class == MatchData
			links.push(md[0])
			#puts md[0]
			md = re.match(md.post_match)
		end
		
		user_tags = {}
		link_tags = {}
		
		users.each do |user|
			#puts 'user: '+user
			if index = string.index(user)
				user_tags[Range.new(index, index+user.length)] = user
			end
		end
		
		links.each do |link|
			#puts 'link: '+link
			if index = string.index(link)
				link_tags[Range.new(index, index+link.length)] = link
			end
		end
		
		#puts 'sending line'
		
		sendtobuffer(string, tags, insert, user_tags, link_tags)
	end
	
	#send the text to the buffer
	def sendtobuffer(string, tags, insert, user_tags, link_tags)
		offset = insert.offset
		#mark = buffer.create_mark(nil, insert, false)
		@buffer.insert(insert, string)
		iter = @buffer.get_iter_at_offset(offset)
		start = iter.offset
		tags.each do |k, v|
			if @buffer.tag_table.lookup(v)
				tag_start = @buffer.get_iter_at_offset(k.begin+start)
				tag_end = @buffer.get_iter_at_offset(k.end+start)
				#puts tag_start.offset, tag_end.offset, '<>'
				@buffer.apply_tag(v, tag_start, tag_end)
				#puts offset, tag_start.offset, tag_end.offset, v.class
				#puts @buffer.get_text(tag_start, tag_end)
			else
				puts 'invalid tag '+v
			end
		end
		
		link_tags.each do |k, v|
			#puts k
			#tag = @buffer.create_tag(v, {})
			name = 'link_'+rand(1000).to_s+'_'+v
			while @buffer.tag_table.lookup(name)#
				name = 'link_'+rand(1000).to_s+'_'+v
			end
			tag = Gtk::TextTag.new(name)
			@buffer.tag_table.add(tag)
			#puts @buffer.tag_table.lookup(name)
			#tag.foreground = 'blue'
			tag_start = @buffer.get_iter_at_offset(k.begin+start)
			tag_end = @buffer.get_iter_at_offset(k.end+start)
			#puts tag_start.offset, tag_end.offset, '<>'
			@buffer.apply_tag(tag, tag_start, tag_end)
			#tag.data['type'] = 'link'
			#tag.data['link'] = v
		end
		
		user_tags.each do |k, v|
			#puts k
			#tag = @buffer.create_tag(v, {})
			name = 'user_'+rand(1000).to_s+'_'+v
			while @buffer.tag_table.lookup(name)#
				name = 'user_'+rand(1000).to_s+'_'+v
			end
			tag = Gtk::TextTag.new(name)
			#tag.foreground = 'blue'
			@buffer.tag_table.add(tag)
			#puts @buffer.tag_table.lookup(name)
			tag_start = @buffer.get_iter_at_offset(k.begin+start)
			tag_end = @buffer.get_iter_at_offset(k.end+start)
			#puts tag_start.offset, tag_end.offset, '<>'
			@buffer.apply_tag(tag, tag_start, tag_end)
			#tag.data['type'] = 'user'
			#tag.data['user'] = v
		end
	end
end

class RootBuffer < Buffer
	attr_reader :servers, :box, :name, :parent, :config, :username, :connected
	def initialize(parent)
		super('Servers')
		@username = ''
		@parent = parent
		@servers = Array.new
		if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
			@box = Gtk::VBox.new
		else
			@box = Gtk::HBox.new
		end
		@box.show
		#@config = @parent.config
		@name = 'servers'
		@box.pack_start(@button)
		@status = INACTIVE
		@connected = true
	end
	
	def redraw
		if @box != Gtk::VBox and ($config['channellistposition'] == 'right' or $config['channellistposition'] == 'left')
			empty_box
			@box = Gtk::VBox.new
		elsif @box != Gtk::HBox and ($config['channellistposition'] == 'top' or $config['channellistposition'] == 'bottom')
			empty_box
			@box = Gtk::HBox.new
		end
		
		@box.pack_start(@button)
		
		@servers.sort
		
		@servers.each do |server|
			server.redraw
			insertintobox(server)
		end
		
		@box.show_all
		return @box
	end
	
	def empty_box
		@box.remove(@button)
		@servers.each do |server|
			@box.remove(server.box)
		end
		@box.destroy
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
			newserver = ServerBuffer.new(name, presence, self)
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
				#pick the right seperator to be using...
				if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
					#puts 'horizontal seperator'
					seperator = Gtk::HSeparator.new
				else
					#puts 'vertical seperator'
					seperator = Gtk::VSeparator.new
				end
				
				if i !=0 and i == @servers.length-1
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					@box.reorder_child(seperator, @servers.length*2)
					@box.reorder_child(newserver.box, @servers.length*2)
					#puts 'a '+ @servers.length.to_s
				elsif i > 0
					#seperator = Gtk::VSeparator.new
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					@box.reorder_child(seperator, (i*2)+1)
					@box.reorder_child(newserver.box, (i*2)+2)
					#puts 'b'+i.to_s
				elsif i == 0 and @servers.length > 1
					#seperator = Gtk::VSeparator.new
					@box.pack_start(seperator, false, false, 5)
					seperator.show
					
					@box.reorder_child(seperator, i+2)
					@box.reorder_child(newserver.box, i+2)
					#puts 'c'
				else
					#puts 'd'
					#seperator = Gtk::VSeparator.new
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

class ServerBuffer < Buffer
	attr_reader :name, :channels, :box, :parent, :config, :username, :presence, :connected, :users
	#attr_writer :username, :presence
	def initialize(name, presence, parent)
		super(name)
		@presence = presence
		#puts @presence
		@username = @presence.deep_clone
		@parent = parent
		@name = name
		@channels = Array.new
		@chats = Array.new
		#@config = getparentwindow.config
		#@buffer = Gtk::TextBuffer.new
		@users = UserList.new
		@button.active = false
		if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
			@box = Gtk::VBox.new
		else
			@box = Gtk::HBox.new
		end
		@box.pack_start(@button, false, false)
		@box.show
		@status = INACTIVE
		#if($config.serverbuttons)
			@button.show
		#end
		@connected = true
	end
	
	def redraw
		if @box != Gtk::VBox and ($config['channellistposition'] == 'right' or $config['channellistposition'] == 'left')
			empty_box
			@box = Gtk::VBox.new
		elsif @box != Gtk::HBox and ($config['channellistposition'] == 'top' or $config['channellistposition'] == 'bottom')
			empty_box
			@box = Gtk::HBox.new
		end
		@box.show
		
		@box.pack_start(@button)
		
		@channels.sort
		
		@channels.each do |channel|
			insertintobox(channel)
		end
	end
		
		
	def empty_box
		@box.remove(@button)
		@channels.each do |channel|
			@box.remove(channel.button)
		end
		@box.destroy
	end
	
	def add(name)
		if name2index(name) != nil
			puts 'You are already connected to #'+name+" on this server"
			return
		end
		newchannel = ChannelBuffer.new(name, self)
		@channels.push(newchannel)
		@channels = @channels.sort
		insertintobox(newchannel)
		return newchannel
	end
	
	def addchat(name)
		#return if @chats[name]
		
		
		newchat = ChatBuffer.new(name, self)
		@chats.push(newchat)
		@chats.sort
		insertintobox(newchat)
		return newchat
	end
	
	def insertintobox(item)
		#insert the widget
		if item.class == ChannelBuffer
			@box.pack_start(item.button, true, true)
			for i in 0...(@channels.length)
				if @channels[i] == item
					@box.reorder_child(item.button, i+1)
					return
				end
			end
		elsif item.class == ChatBuffer
			@box.pack_start(item.button, true, true)
			for i in 0...(@chats.length)
				if @chats[i] == item
					@box.reorder_child(item.button, (i+@channels.length+1))
					return
				end
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
	
	def chat_exists?(name)
		@chats.each do |chat|
			if chat.name == name
				return chat
			end
		end
		return false
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
	
	def getnetworkpresencepair
		return @name, @presence
	end
	
end

class ChannelBuffer < Buffer
	attr_reader :name, :server, :config, :userlist, :renderer, :column, :connected, :users, :topic
	attr_writer :topic
	def initialize(name, server)
		super(name)
		@server = server
		@name = name
		#puts @server.username
		#@config = getparentwindow.config
		#@buffer = Gtk::TextBuffer.new
		@userlist = Gtk::ListStore.new(String)
		@renderer = Gtk::CellRendererText.new
		@column = Gtk::TreeViewColumn.new("Users", @renderer)
		@column.add_attribute(@renderer, "text",  0)
		@userlist.clear
		@status = INACTIVE
		@topic = ''
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
		@users.sort
		
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
	
	def username
		return @server.username
	end
	
	#~ def changeuser(old, new)
		#~ if @users[old]
			#~ @users[new] = @users[old]
			#~ @users[new][0] = new
			#~ @users.delete(old)
		#~ end
	#~ end
	def getnetworkpresencepair
		return @server.getnetworkpresencepair
	end
	
	def tabcomplete(substr)
		if !@tabcomplete
			list = @users.sort
			@tabcomplete = TabComplete.new(substr, list)
			if @tabcomplete.firstmatch
				return @tabcomplete.firstmatch.name
			else
				clear_tabcomplete
				return nil
			end
		else
			return @tabcomplete.succ.name
		end
	end
	
	def clear_tabcomplete
		@tabcomplete = nil
	end
end

class ChatBuffer < Buffer
	attr_reader :name, :server
	def initialize(name, server)
		super(name)
		@server = server
		@name = name
		#puts @server.username
		#@config = getparentwindow.config
		#@buffer = Gtk::TextBuffer.new
		@userlist = Gtk::ListStore.new(String)
		@renderer = Gtk::CellRendererText.new
		@column = Gtk::TreeViewColumn.new("Users", @renderer)
		@column.add_attribute(@renderer, "text",  0)
		@userlist.clear
		@status = INACTIVE
		@topic = ''
		@button.label= @name
		@button.active = false
		@button.show
		@users = UserList.new
		@connected = true
		
		@useriters = []
	end
	def username
		return @server.username
	end
end