#define some status constants
INACTIVE = 0
NEWDATA = 1
NEWMSG = 2
HIGHLIGHT = 3
ACTIVE = 0

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
TOPIC = 8
MODECHANGE = 9
CTCP = 10

class Buffer
	attr_reader :oldendmark, :currentcommand, :buffer, :button
	attr_writer :currentcommand
    extend Plugins
    include PluginAPI
	def initialize(name)
		@buffer = Gtk::TextBuffer.new
        16.times do |x|
            @buffer.create_tag('color'+x.to_s, {'foreground_gdk'=>$config['color'+x.to_s]}) if $config['color'+x.to_s]
        end
        @buffer.create_tag('bold', {'weight' =>  Pango::FontDescription::WEIGHT_BOLD})
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@button = Gtk::ToggleButton.new(name)
		@button.active = false
		@togglehandler = @button.signal_connect('toggled')do |w|
			switchchannel(self)
		end
        
        @button.signal_connect('button_press_event')do |w, event|
            if event.button == 3
                rightclickmenu(event)
            end
		end
        @modes = ['message', 'usermessage', 'join', 'userjoin', 'part', 'userpart', 'error', 'notice', 'topic', 'modechange', 'ctcp']
	end
    
    def rightclickmenu(event)
        menu = genmenu
        return unless menu
        menu.show_all
        menu.popup(nil, nil, event.button, event.time)
        return true
    end
    
    def genmenu
        return nil
    end
    
    def set_tab_label(label)
        r = Regexp.new('([^_])(_)([^_])')
        @button.label = label.gsub(r) {|x| $1+$2+'_'+$3}
    end
	
    #trigger a channel switch...?
	def switchchannel(channel)
		return if @button.toplevel.class != Gtk::Window or !$main.window
		$main.window.switchchannel(channel)
	end
	
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
	
    #set a channel as active
	def activate
		@button.signal_handler_block(@togglehandler)
		@button.active=true
		@button.signal_handler_unblock(@togglehandler)
		@status = ACTIVE
		recolor
		return @buffer
	end
	
    #set a channel as inactive
	def deactivate
		@button.signal_handler_block(@togglehandler)
		@button.active=false
		@button.signal_handler_unblock(@togglehandler)
		@status = INACTIVE
		recolor
	end
	
    #update the status of a channel
	def setstatus(status)
		if(status > @status)
			@status = status
			recolor
		end
	end
	
    #disconnect a channel
	def disconnect
        #puts caller
		set_tab_label('('+@name+')')
        if $config['number_tabs'] and @number
            set_tab_label(@number.to_s+':'+@button.label)
        end
        @connected = false unless @connected.nil?
	end
	
    #reconnect a channel
	def reconnect
		set_tab_label(@name)
        if $config['number_tabs'] and @number
            set_tab_label(@number.to_s+':'+@button.label)
        end
		@connected = true
	end
	
	#set the button color
	def recolor
		label = @button.child
		label.modify_fg(Gtk::STATE_NORMAL, $config.getstatuscolor(@status))
        if @button.active?
            label.modify_fg(Gtk::STATE_PRELIGHT, $config.getstatuscolor(0))
        else
            label.modify_fg(Gtk::STATE_PRELIGHT, $config.getstatuscolor(@status))
        end
	end
    
    #send an event from the user to the buffer
    def send_user_event(line, type)
        time = Time.new
        time = time - $main.drift if $config['canonicaltime'] == 'server'
        line['time'] = time
        send_event(line, type)
    end
    
    #send a line to the buffer
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
        
        cmd = 'buffer_'+@modes[type]
        if self.respond_to?(cmd)
            #puts cmd
            res = callback(cmd, line, pattern, users, insert_location)
            return if res === true
            #res.each {|x| puts x}
            pattern, users, insert_location = self.send(cmd, *res)
        else
            return
        end
		
		if pattern.length > 0
			recolor
			if insert_location == BUFFER_START
				if @buffer.char_count > 0
					pattern += "\n"
				end
			elsif insert.offset != 0
				pattern = "\n"+pattern
			end
			colortext(pattern, insert, users)
		end
		
		@newlineend = @buffer.end_iter
		
		$main.scroll_to_end(self)
			
	end
    
    def buffer_message(line, pattern, users, insert_location)
        setstatus(NEWMSG) if insert_location == BUFFER_END
        if line['type'] == 'action' and line['nick']
            pattern += $config['action'].deep_clone
            pattern['%u'] = line['nick']
            pattern['%m'] = line['msg'] if line['msg']
        else
            pattern += $config['message'].deep_clone
            if line['nick']
                pattern['%u'] = line['nick']
                users.push(line['nick'])
            end
            pattern['%m'] = line['msg'] if line['msg']
        end
        return [pattern, users, insert_location]
    end
    
    def buffer_ctcp(line, pattern, users, insert_location)
        puts 'ctcp line'
        if line['name'] == 'action' and line['nick']
            puts 'an action'
            pattern += $config['action'].deep_clone
            pattern['%u'] = line['nick']
            pattern['%m'] = line['args'] if line['args']
        end
        return [pattern, users, insert_location]
    end
    
    def buffer_usermessage(line, pattern, users, insert_location)
        setstatus(NEWMSG) if insert_location == BUFFER_END
        pattern += $config['usermessage'].deep_clone
        if username
            pattern['%u'] = username
            users.push(username)
        end
        pattern['%m'] = line['msg'] if line['msg']
        return [pattern, users, insert_location]
    end
    
    def buffer_join(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config['join'].deep_clone
        pattern['%u'] = line['name']
        users.push(line['name'])
        pattern['%c'] = line['channel']
        if user = @users[line['name']] and user.hostname
            pattern['%h'] = user.hostname
        elsif line['address']
            pattern['%h'] = line['address']
        end
        return [pattern, users, insert_location]
    end    
        
    def buffer_userjoin(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config['userjoin'].deep_clone
        pattern['%c'] = line['channel']
        return [pattern, users, insert_location]
    end
    
    def buffer_part(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
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
       return [pattern, users, insert_location]
    end
    
    def buffer_userpart(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config['userpart'].deep_clone
        pattern['%c'] = line['channel']
        return [pattern, users, insert_location]
    end

    def buffer_error(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config['error'].deep_clone
        pattern['%m'] = line['err']
        return [pattern, users, insert_location]
    end
    
    def buffer_notice(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config['notice'].deep_clone
        pattern['%m'] = line['msg']
        return [pattern, users, insert_location]
    end
    
    def buffer_topic(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        if line['init'] and line['line'] == 2
            pattern += $config['topic_setby'].deep_clone
            pattern['%c'] = line['channel']
            pattern['%u'] = line['topic_set_by']
            pattern['%a'] = Time.at(line['topic_timestamp'].to_i).strftime('%c')
            users.push(line['topic_set_by'])
        elsif line['init'] and line['line'] == 1
            pattern += $config['topic'].deep_clone
            pattern['%c'] = line['channel']
            pattern['%t'] = line['topic']
            #~ line2 = line.deep_clone
            #~ line2['line'] = 2
            #~ Thread.new{
            #~ sleep 0.5
            #~ send_event(line2, TOPIC, insert_location)
            #~ }
        elsif line['topic']
            pattern += $config['topic_change'].deep_clone
            pattern['%t'] = line['topic']
            pattern['%u'] = line['topic_set_by']
            users.push(line['topic_set_by'])
        end
       return [pattern, users, insert_location]
    end
    
    def buffer_modechange(line, pattern, users, insert_location)
        if line['add']
            pattern += $config['add_mode'].deep_clone
        elsif line['remove']
            pattern += $config['remove_mode'].deep_clone
        else
            return
        end
        pattern['%s'] = line['source_presence']
        pattern['%m'] = line['status']
        pattern['%u'] = line['name']
        users.push(line['source_presence'], line['name'])
        
        return [pattern, users, insert_location]
    end
    
    def endmark
        return @buffer.create_mark('end', @buffer.end_iter, false)
    end
	
	#add a command to the command buffer
	def addcommand(string)
		return if string.length == 0
		@commandbuffer.push(string)
		while @commandbuffer.length > $config['commandbuffersize'].to_i
			@commandbuffer.delete_at(0)
		end
		@commandindex = @commandbuffer.length-1
	end
	
	#get the last command in the command buffer
	def getlastcommand
        puts @commandindex
        command = @commandbuffer[@commandindex]
		@commandindex -=1 if @commandindex != 0
		return command
	end
	
	#get the next command in the command buffer
	def getnextcommand
        puts @commandindex
		 if @commandindex >= @commandbuffer.length-1
			return ''
		else
            @commandindex +=1
			return @commandbuffer[@commandindex]
		end
	end
	
	#parse the colors in the text
	def colortext(string, insert, users)
		re = /((%\d).+?\2)/
		md = re.match(string)
		
		tags = {}
		
		while md.class == MatchData
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
        
        re = /((\x02).+?\2)/
		md = re.match(string)
        re2 = /\x02/
        
        while md.class == MatchData
            text = md[0].gsub(re2, '')
            
            string[md[0]] = text
            
            start, stop = md.offset(1)
            
            stop -= (md[2].length)*2
			tags[Range.new(start, stop)] = 'bold'
            
            md = re.match(string)
        end
		
		links = []
		
		re = /(([a-zA-Z]+\:\/\/|[a-zA-Z0-9]+\.)[a-zA-Z0-9.-]+\.[a-zA-Z.]+([^\s\n\(\)\[\]\r]+|))/
		md = re.match(string)
		
		while md.class == MatchData
			links.push(md[0])
			md = re.match(md.post_match)
		end
		
		user_tags = {}
		link_tags = {}
		
		users.each do |user|
			if index = string.index(user)
				user_tags[Range.new(index, index+user.length)] = user
			end
		end
		
		links.each do |link|
			if index = string.index(link)
				link_tags[Range.new(index, index+link.length)] = link
			end
		end
		
		sendtobuffer(string, tags, insert, user_tags, link_tags)
	end
	
	#send the text to the buffer
	def sendtobuffer(string, tags, insert, user_tags, link_tags)
		offset = insert.offset
		@buffer.insert(insert, string)
		iter = @buffer.get_iter_at_offset(offset)
		start = iter.offset
		tags.each do |k, v|
			if @buffer.tag_table.lookup(v)
				tag_start = @buffer.get_iter_at_offset(k.begin+start)
				tag_end = @buffer.get_iter_at_offset(k.end+start)
				@buffer.apply_tag(v, tag_start, tag_end)
			else
				puts 'invalid tag '+v
			end
		end
		
		link_tags.each do |k, v|
			name = 'link_'+rand(1000).to_s+'_'+v
			while @buffer.tag_table.lookup(name)#
				name = 'link_'+rand(1000).to_s+'_'+v
			end
			tag = Gtk::TextTag.new(name)
			@buffer.tag_table.add(tag)
			tag_start = @buffer.get_iter_at_offset(k.begin+start)
			tag_end = @buffer.get_iter_at_offset(k.end+start)
			@buffer.apply_tag(tag, tag_start, tag_end)
		end
		
		user_tags.each do |k, v|
			name = 'user_'+rand(1000).to_s+'_'+v
			while @buffer.tag_table.lookup(name)#
				name = 'user_'+rand(1000).to_s+'_'+v
			end
			tag = Gtk::TextTag.new(name)
			@buffer.tag_table.add(tag)
			tag_start = @buffer.get_iter_at_offset(k.begin+start)
			tag_end = @buffer.get_iter_at_offset(k.end+start)
			@buffer.apply_tag(tag, tag_start, tag_end)
		end
	end
end

#The 'Servers' buffer, not sure if this will be required in the future...
class RootBuffer < Buffer
	attr_reader :servers, :box, :name, :parent, :config, :username, :connected, :server
	def initialize(parent)
		super('Servers')
		@username = ''
		@parent = parent
        @server = self
		@servers = Array.new
		#~ if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
			#~ @box = Gtk::VBox.new
		#~ else
			#~ @box = Gtk::HBox.new
		#~ end
		#~ @box.show
		@name = 'servers'
#		@box.pack_start(@button)
		@status = INACTIVE
		@connected = true
        @button.show
        redraw
	end
	
    #redraw the buttonbox
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
            unless server.connected.nil?
                server.redraw
                insertintobox(server)
            end
		end
		
		@box.show_all
        renumber
		return @box
	end
	
    #remove all the buttons from a box
	def empty_box
        return unless @box
       # puts @box, @button
		@box.remove(@button) if @button
		@servers.each do |server|
			@box.remove(server.box)
		end
		@box.destroy
	end
	
    #add a network
	def add(name, presence)
		return if !presence or !name
		x = name2index(name, presence)
		if x  != nil and x.connected
			puts "You are already connected to " + name + "for presence "+ presence
			return
		else
			newserver = ServerBuffer.new(name, presence, self)
			@servers.push(newserver)
			@servers = @servers.sort
			insertintobox(newserver)
			return newserver
		end
	end
	
    #add a button to the button box
	def insertintobox(newserver)
        return if newserver.connected.nil?
		#insert the widget
		@box.pack_start(newserver.box, true, true)
		for i in 0...(@servers.length)
			if @servers[i] == newserver
				#pick the right seperator to be using...
				if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
					seperator = Gtk::HSeparator.new
				else
					seperator = Gtk::VSeparator.new
				end
				
				if i !=0 and i == @servers.length-1
					@box.pack_start(seperator, false, false, 5)
					@box.reorder_child(seperator, @servers.length*2)
					@box.reorder_child(newserver.box, @servers.length*2)
				elsif i > 0
					@box.pack_start(seperator, false, false, 5)
					@box.reorder_child(seperator, (i*2)+1)
					@box.reorder_child(newserver.box, (i*2)+2)
				elsif i == 0 and @servers.length > 1
					@box.pack_start(seperator, false, false, 5)
					@box.reorder_child(seperator, i+2)
					@box.reorder_child(newserver.box, i+2)
				else
					@box.pack_start(seperator, false, false, 5)
					@box.reorder_child(seperator, @servers.length+1)
					@box.reorder_child(newserver.box, @servers.length+1)
				end
                seperator.show
			end
		end
	end
    
    def get_network_by_name(name)
        results = []
        @servers.each do |server|
            if server.name == name
                results.push(server)
            end
        end
        
        if results.length == 0
            return nil
        else
            return results
        end
    end
	
    #function for getting a network when you pass a server/presence pair
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
    
    def renumber
        i = 1
        @tabs = []
        servers.each do |server|
            next if server.connected.nil?
            server.channels.each do |channel|
                next if channel.connected.nil?
                #puts channel.connected
                channel.set_number(i)
                #puts 'numbering '+channel.name+' as '+i.to_s
                @tabs[i] = channel
                i += 1
            end
            
            server.chats.each do |chat|
                next if chat.connected.nil?
                chat.set_number(i)
                @tabs[i] = chat
                i += 1
            end
        end
    end
    
    def number2tab(number)
        return @tabs[number.to_i]
    end
    
end

#buffer used for networks
class ServerBuffer < Buffer
	attr_reader :name, :channels, :box, :parent, :config, :username, :presence, :connected, :users, :server, :chats, :loggedin, :bufferedcommands
    attr_writer :bufferedcommands, :loggedin
	def initialize(name, presence, parent)
		super(name)
        @server = self
		@presence = presence
		@username = @presence.deep_clone
		@parent = parent
		@name = name
		@channels = Array.new
		@chats = Array.new
		@users = UserList.new
		@button.active = false
		#~ if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
			#~ @box = Gtk::VBox.new
		#~ else
			#~ @box = Gtk::HBox.new
		#~ end
		#~ @box.pack_start(@button, false, false)
		#~ @box.show
		@status = INACTIVE
		#if($config.serverbuttons)
			@button.show
		#end
		@connected = nil
        @loggedin = false
        @bufferedcommands = []
	end
	
    def connect
        #puts 'connected '+@name
        @connected = true
        @button.show
        @parent.redraw
    end
    
    def reconnect
        super
        @loggedin = false
    end
    
    #redraw the button box
	def redraw
		if @box != Gtk::VBox and ($config['channellistposition'] == 'right' or $config['channellistposition'] == 'left')
			empty_box
			@box = Gtk::VBox.new
		elsif @box != Gtk::HBox and ($config['channellistposition'] == 'top' or $config['channellistposition'] == 'bottom')
			empty_box
			@box = Gtk::HBox.new
		end

		@box.pack_start(@button)
		
		@channels.sort! {|x, y| x.name <=> y.name}
		
		@channels.each do |channel|
			insertintobox(channel)
		end
        @box.show_all
	end
    
    #remove all the buttons from the box
	def empty_box(destroy = true)
        return unless @box
		@box.remove(@button)
		@channels.each do |channel|
			@box.remove(channel.button)
		end
		@box.destroy if destroy
	end
	
    #add a channel to the network
	def add(name)
		if channels.include?(name)
			puts 'You are already connected to '+name+" on this server"
			return
		end
		newchannel = ChannelBuffer.new(name, self)
		@channels.push(newchannel)
		@channels.sort! {|x, y| x.name <=> y.name}
		insertintobox(newchannel)
        @parent.renumber
		return newchannel
	end
	
    #add a chat to the network
	def addchat(name)
		newchat = ChatBuffer.new(name, self)
		@chats.push(newchat)
		@chats.sort! {|x, y| x.name <=> y.name}
		insertintobox(newchat)
		return newchat
	end
    
    #insert the button into the box
	def insertintobox(item)
        return if item.connected.nil?
        #@channels.sort! {|x, y| x.name <=> y.name}
		#insert the widget
        #@channels.each {|channel| puts channel.name unless channel.connected.nil?}
        #puts ''
		if item.class == ChannelBuffer
			@box.pack_start(item.button, true, true)
            i = 0
			@channels.each do |channel|
                next if channel.connected.nil?
                #puts @channels[i].name+' at '+i.to_s
				if channel == item
                    #puts i, @channels.length
                    @box.reorder_child(item.button, i+1)
                    #puts item.name+' goes after '+(i-1).to_s+' and before '+(i+1).to_s
                    i+=1
					next
				end
                i+=1
			end
		elsif item.class == ChatBuffer
            i = 0
            @channels.each {|channel| i+=1 unless channel.connected.nil?}
            #puts i
			@box.pack_start(item.button, true, true)
			@chats.each do |chat|
                next if chat.connected.nil?
                #puts @channels[i].name+' at '+i.to_s
				if chat== item
                    #puts i, @channels.length
                    @box.reorder_child(item.button, i+1)
                    #puts item.name+' goes after '+(i-1).to_s+' and before '+(i+1).to_s
                    i+=1
					next
				end
                i+=1
			end
		#~ elsif item.class == ChatBuffer
			#~ @box.pack_start(item.button, true, true)
			#~ for i in 0...(@chats.length)
				#~ if @chats[i] == item
					#~ @box.reorder_child(item.button, (i+@channels.length+1))
					#~ return
				#~ end
			#~ end
		end
	end
    
    def removefrombox(button)
        @box.remove(button)
        #~ @box.each_forall do |x|
            #~ puts x
        #~ end
        #children = @box.children
        #puts children
        #children.each { |x| puts x}
        $main.switchchannel(getnextchannel)
        @parent.renumber
    end
    
    def getnextchannel
        nextchan = nil
        @channels.each do |channel|
            unless channel.connected.nil?
                nextchan = channel
                break
            end
        end
        
        if !nextchan
            unless self.connected.nil?
                nextchan = self
            else
                nextchan = @parent
            end
        end
        
        return nextchan
    end

    #redraw the box
	def redrawbox
		for i in 0...(@channels.length)
			@box.remove(@channels[i].button)
		end
		for i in 0...(@channels.length)
			@box.pack_start(@channels[i].button)
		end
	end
	
    #method to get the channel object when passing the channel name
	def [](key)
		if key.kind_of?(Integer)
			return @channels[key]
		else
			return name2index(key)
		end
	end
	
    #check if a chat with a particular person exists
	def has_chat?(name)
		@chats.each do |chat|
			if chat.name == name
				return chat
			end
		end
        puts 'no chat for '+name
		return false
	end
	
	def name2index(name)
		for i in 0...@channels.length
			return @channels[i] if name == @channels[i].name
		end
		return nil
	end
	
    #get the parent window...?
	def getparentwindow
		return @parent.parent
	end
	
    #set the username on this network
	def set_username(name)
		@username = name
	end
	
	def getnetworkpresencepair
		return @name, @presence
	end
    
    def genmenu
        menu = Gtk::Menu.new
        item = Gtk::MenuItem.new('Disconnect')
        item.signal_connect('activate') do |w|
            $main.send_command('disconnect'+@name, "presence disconnect;network="+@name+";presence="+@presence)
            #disconnect
        end
        menu.append(item)
        item = Gtk::MenuItem.new('Close')
        item.signal_connect('activate') do |w|
            close
        end
        menu.append(item)
        return menu
    end
    
    def close
        if @connected
            $main.send_command('disconnect'+@name, "presence disconnect;network="+@name+";presence="+@presence)
        end
        @connected = nil
        @number = nil
        set_tab_label(@name)
        @server.removefrombox(@button)
    end
	
end

#buffer for channels
class ChannelBuffer < Buffer
	include TabCompleteModule
	attr_reader :name, :server, :config, :userlist, :renderer, :modecolumn, :usercolumn, :connected, :users, :topic, :usersync, :eventsync
	attr_writer :topic, :usersync, :eventsync
	def initialize(name, server)
		super(name)
        @usersync = false
        @eventsync = false
		@server = server
		@name = name
		@userlist = Gtk::ListStore.new(String, String)
		@renderer = Gtk::CellRendererText.new
		@modecolumn = Gtk::TreeViewColumn.new("Mode", @renderer, :text=>0)
        @usercolumn = Gtk::TreeViewColumn.new("Users", @renderer, :text=>1)
		@userlist.clear
		@status = INACTIVE
		@topic = ''
		set_tab_label(@name)
		@button.active = false
		#@button.show
		@users = ChannelUserList.new
		@connected = nil
        @number = nil
		
		@useriters = []
	end
    
    def connect
        @connected = true
        @button.show
        #@server.channels.sort
        #@server.channels.each {|channel| puts channel.name unless channel.connected.nil?}
        @server.insertintobox(self)
        set_tab_label(@name)
        @server.parent.renumber
        #@server.parent.redraw
        #server.redraw
    end
    
    def close
        if @connected
            $main.send_command('part', "channel part;network="+@server.name+";presence="+@server.presence+";channel="+@name)
        end
        @connected = nil
        @number = nil
        #@button.label = @name.gsub('_', '__')
        set_tab_label(@name)
        @server.removefrombox(@button)
    end
    
    def genmenu
        menu = Gtk::Menu.new
        item = Gtk::MenuItem.new('Part')
        item.signal_connect('activate') do |w|
            $main.send_command('part', "channel part;network="+@server.name+";presence="+@server.presence+";channel="+@name)
            #disconnect
        end
        menu.append(item)
        item = Gtk::MenuItem.new('Close')
        item.signal_connect('activate') do |w|
            close
        end
        menu.append(item)
        return menu
    end
	
    def set_number(num)
        @number = num
        if $config['number_tabs']
            md = /^(\d+:).+$/.match(@button.label)
            set_tab_label(@button.label.gsub(md[1], '')) if md
            set_tab_label(@number.to_s+':'+@button.label)
        end
    end
    
    #add this channel to the server
	def add(name)
		@server.add(name)
	end
	
    #add a user
	#~ def adduser(name, init = true)
		#~ if @server.users[name]
			#~ if ! @users[name]
				#~ @users.add(@server.users[name])
				#~ if !init
					#~ drawusers
				#~ end
			#~ end
		#~ else
			#~ puts 'Unknown user '+name
		#~ end
	#~ end
	
    #draw the user list
	def drawusers
		@users.sort!
        
		if @useriters.length == 0
			@users.users.each do |user|
				iter = @userlist.append
				iter[0] = user.get_modes
                iter[1] = user.name
                uiter = Gtk::TreeRowReference.new(@userlist, iter.path)
				@useriters.push(uiter)
			end
		else
			i = 0
			@users.users.each do |user|
				if !@useriters[i]
					iter = @userlist.append
                    iter[0] = user.get_modes
					iter[1] = user.name
                    uiter = Gtk::TreeRowReference.new(@userlist, iter.path)
                    @useriters.push(uiter)
					return
				end
                
                unless @useriters[i].valid?
                    i+=1
                    next
                end
                
                 iter = @userlist.get_iter(@useriters[i].path)
				res = user.comparetostring(iter[1], iter[0])
				if res == 0
				elsif res == 1
                    @userlist.remove(iter)
                    @useriters.delete_at(i)
				elsif res == -1
					niter = @userlist.insert_before(iter)
                    niter[0] = user.get_modes
					niter[1] = user.name
                    uiter = Gtk::TreeRowReference.new(@userlist, niter.path)
					@useriters[i] = [uiter, @useriters.at(i)]
					@useriters.flatten!
				end
				
				i += 1
			end
			while @users.length < @useriters.length
				@userlist.remove(@userlist.get_iter(@useriters[@useriters.length-1].path))
				@useriters.delete_at(@useriters.length-1)
			end
		end
	end
	
    #remove all the users
	def clearusers
		@userlist.clear
        @useriters.clear
	end
	
    #remove a user
	#~ def deluser(user, deinit = false)
		#~ if @users[user]
			#~ @users.remove(user)
			#~ @users.sort
			#~ if !deinit
				#~ drawusers
			#~ end
		#~ end
	#~ end
	
    #get the username
	def username
		return @server.username
	end
    
	def getnetworkpresencepair
		return @server.getnetworkpresencepair
	end
end

#buffer used for 2 person chats
class ChatBuffer < Buffer
	attr_reader :name, :server, :connected
	def initialize(name, server)
		super(name)
		@server = server
		@name = name
		@userlist = Gtk::ListStore.new(String)
		@renderer = Gtk::CellRendererText.new
		@column = Gtk::TreeViewColumn.new("Users", @renderer)
		@column.add_attribute(@renderer, "text",  0)
		@userlist.clear
		@status = INACTIVE
		@topic = ''
		set_tab_label(@name)
		@button.active = false
		#@button.show
		@users = UserList.new
		@connected = nil
        @number = nil
		
		@useriters = []
	end
    
    def set_number(num)
        @number = num
        if $config['number_tabs']
            md = /^(\d+:).+$/.match(@button.label)
            set_tab_label(@button.label.gsub(md[1], '')) if md
            set_tab_label(@number.to_s+':'+@button.label)
        end
    end
    
    def connect
        @connected = true
        @button.show
        @server.chats.sort
        @server.insertintobox(self)
        @server.parent.renumber
        #@server.parent.redraw
    end
    
    def close
        @server.removefrombox(@button)
        @connected = nil
        @number = nil
    end
    
    def genmenu
        menu = Gtk::Menu.new
        item = Gtk::MenuItem.new('Close')
        item.signal_connect('activate') do |w|
            close
        end
        menu.append(item)
        return menu
    end
    
    #get the username
	def username
		return @server.username
	end
    
    def rename(name)
        @name = name
        #@button.label = name.gsub('_', '__')
        set_tab_label(name)
    end
end