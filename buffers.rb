class Buffer
	attr_reader :oldendmark, :currentcommand, :liststore, :button, :links, :view
	attr_writer :currentcommand
    extend Plugins
    include PluginAPI
	def initialize(name)
        @links = []
        @view = Scw::View.new
        @liststore = Gtk::ListStore.new(Scw::Timestamp, Scw::Presence, String)
        @view.model = @liststore
        #@view.align_presences = true
        @view.scroll_on_append = true
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@button = Gtk::ToggleButton.new(name)
		@button.active = false
		@togglehandler = @button.signal_connect('toggled')do |w|
			switchchannel(self)
		end
        
        @view.signal_connect("activated") do |view,id,data|
          puts "Activated #{id} with #{data}"
        end
        
        @linebuffer = []
        
        @button.signal_connect('button_press_event')do |w, event|
            if event.button == 3
                rightclickmenu(event)
            end
		end
        @modes = ['message', 'usermessage', 'join', 'userjoin', 'part', 'userpart', 'error', 'notice', 'topic', 'modechange', 'ctcp']
	end
    
    def update_colors
        #puts 'updating colors for '+@button.label
        #~ 16.times do |x|
            #~ if $config['color'+x.to_s] and tag = @buffer.tag_table.lookup('color'+x.to_s)
                #~ #puts 'updating '+tag.to_s
                #~ tag.foreground_gdk = $config['color'+x.to_s]
            #~ elsif $config['color'+x.to_s] 
                #~ @buffer.create_tag('color'+x.to_s, {'foreground_gdk'=>$config['color'+x.to_s]}) if $config['color'+x.to_s]
            #~ end
        #~ end
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
        recolor
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
		return @view
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
        return if $main.quitting
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
        
        x = Line.new
        
        line.each do |k,v|
            x[k.to_sym] = v
        end
        
        line = x
        time = Time.new
        time = time - $main.drift if $config['canonicaltime'] == 'server'
        line[TIME] = time
        line[ID] = 'client'+rand(100).to_s
        send_event(line, type)
    end
    
    #send a line to the buffer
	def send_event(line, type, insert_location=BUFFER_END)
		return if !@connected
        
        raise ArgumentError unless line.class == Line
		
		if insert_location == BUFFER_END
			#insert = @buffer.end_iter
            @linebuffer.push(line)
		elsif insert_location == BUFFER_START
			#insert = @buffer.start_iter
            @linebuffer.unshift(line)
		end
        
        pattern = ''
        
        uname = ''
        
        if line[MSG]
            re= %r{((((http|ftp|irc|https)://|)([\w\-]+\.)+[a-zA-Z]{2,4}|(\d{1,3}\.){3}(\d{1,3}))([.\/]{1}[^\s\n\(\)\[\]\r]+|))}
            md = re.match(line[MSG])
            
            while md.class == MatchData
                if md[0].scan('.').size >= 2 or md[0].scan('://').size > 0
                    dup = false
                    @links.each_with_index do |link, index|
                        next if dup == true or !link['timestamp']
                        if link['link'] == md[0]
                            dup = true
                            #puts 'link is a dup'
                            break
                        elsif line[TIME].to_i < link['timestamp']
                            @links.insert(index, {'link' => md[0], 'name' => line[PRESENCE].to_s, 'timestamp' => line[TIME].to_i, 'time' => Time.at(line[TIME].to_i).strftime('%H:%M')})
                            dup = true
                            #puts 'adding link'
                            break
                        end
                    end
                    @links.insert(-1, {'link' => md[0], 'name' => line[PRESENCE].to_s, 'timestamp' => line[TIME].to_i, 'time' => Time.at(line[TIME].to_i).strftime('%H:%M')}) unless dup
                end
                md = re.match(md.post_match)
            end
        end
		
		links = []
		users = []
        
        local = self
        
        begin
            cmd = 'buffer_'+type
            if self.respond_to?(cmd)
                res = callback(cmd, line, pattern, uname, users, insert_location)
                return if res === true
                res2 = self.send(cmd, *res)
                uname, pattern, users, insert_location = callback_after(cmd, *res2)
            else
                return
            end
        #rescue any exceptions...
        rescue =>exception
            puts 'Error sending : '+$!
            puts exception.backtrace
        end
        
        #puts parse_tags(uname), parse_tags(pattern)
		
		if pattern.length > 0
			recolor
			if insert_location == BUFFER_START
                #iter = @liststore.prepend
                #iter[0] = pattern
			elsif insert_location == BUFFER_END
                iter = @liststore.append
                iter[0] = line[TIME].to_i
                iter[1] = parse_tags(uname)
                iter[2] = parse_tags(pattern)
			end
		end
		
		$main.scroll_to_end(self)
			
	end
    
    def xhtml_im2pango(string)
        re = /\<span style=[\"\'](.+?)[\"\']\>([^\<]+)\<\/span\>/i
        md = re.match(string)
        
        while md.class == MatchData
            x = parse_style(md[1])
            
            replacement = '<s '+x+'>'+md[2]+'</s>'
            
            string.sub!(md[0], replacement)
            
            md = re.match(string)
        end
        
        return string.gsub!('<s ', '<span ').gsub!('</s>', '</span>')
    end
    
    def parse_style(style)
        result = []
        styles = style.split(';').map{|e| e.downcase.strip}
        
        styles.each do |style|
            attribute, value = style.split(':', 2).map{|e| e.strip}
            
            if TAGMAP[attribute]
                attribute = TAGMAP[attribute]
            elsif attribute == 'text-decoration' and value == 'underline'
                attribute = 'underline'
                value = 'single'
            end
            
            if attribute == 'foreground' or attribute == 'background'
                re = Regexp.new('#[a-fA-F0-9]+')
                #pad any hex colors out to 7 characters
                while value =~ re and value.length < 7
                    value['#'] = '#0'
                end
            end
            
            result.push(attribute+'="'+value+'"')
        end
        
        return result.join(' ')
    end
    
    def parse_tags(string)
        re = /((%(C[0-9]{1}[0-5]*|U|B|I))(.+?)\2)/
		md = re.match(string)
		
		while md.class == MatchData
            
            tag = nil
            
            if md[2] =~ /^%C[0-9]{1}[0-5]*$/
                colorid = md[2].gsub!('%C', '')
                tag = 'span'
                attributes = 'foreground="'+$config['color'+colorid].to_hex+'"'
                
            elsif md[2] == '%U'
                tag = 'u'
                
            elsif md[2] == '%B'
                tag = 'b'
                
            elsif md[2] == '%I'
                tag = 'i'
            end
            
            new = md[4]
            
            if attributes
                x = '<'+tag+' '+attributes+'>'
            else
                x = '<'+tag+'>'
            end
            
            y = '</'+tag+'>'
            
            new = x+new+y
            
            string.sub!(md[1], new)

			md = re.match(string)
		end
        
        #strip out any empty patterns
        re = /((%(C[0-9]{1}[0-5]*|U|B|I))\2)/
        md = re.match(string)
        while md.class == MatchData
            string.sub!(md[0], '')
            md = re.match(string)
        end
        
        re= %r{((((http|ftp|irc|https)://|)([\w\-]+\.)+[a-zA-Z]{2,4}|(\d{1,3}\.){3}(\d{1,3}))([.\/]{1}[^\s\n\(\)\[\]\r]+|))}
		md = re.match(string)
		
		while md.class == MatchData
            if md[0].scan('.').size >= 2 or md[0].scan('://').size > 0
                links.push(md[0])
                string.sub!(md[0], '<action id="url">'+md[0]+'</action>')
            end
			md = re.match(md.post_match)
		end
        
        
        return string
    end
    
    def presence2username(name, padding=true)
        return name unless $config['show_usermode']
        if self.class == ChannelBuffer
            if users.include?(name)
                user = users[name]
                mode = user.get_modes
                mode = ' ' if mode =='' and padding and $config['pad_usermode']
                return mode+name
            end
        end
        return name
    end
    
    def buffer_message(line, pattern, uname, users, insert_location)
        setstatus(NEWMSG) if insert_location == BUFFER_END
        if line[TYPE] == 'action' and line[PRESENCE]
            pattern = $config.get_pattern('action')
            pattern['%u'] = presence2username(line[PRESENCE], false)
            if line[MSG_XHTML]
                pattern = escape_xml(pattern)
                pattern['%m'] = xhtml_im2pango(line[MSG_XHTML])
            else
                pattern['%m'] = line[MSG].to_s
                pattern = escape_xml(pattern)
            end
        else
            pattern = $config.get_pattern('message')
            if line[PRESENCE]
                uname = $config.get_pattern('otherusernameformat')
                uname = escape_xml(uname)
                uname['%u'] = '<action id="user">'+escape_xml(presence2username(line[PRESENCE]))+'</action>'
                users.push(line[PRESENCE])
            end
            if line[MSG_XHTML]
                pattern = escape_xml(pattern)
                pattern['%m'] = xhtml_im2pango(line[MSG_XHTML])
            elsif line[MSG]
                pattern['%m'] = line[MSG]
                pattern = escape_xml(pattern)
            else
                pattern = escape_xml(pattern)
            end
        end
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_usermessage(line, pattern, uname, users, insert_location)
        setstatus(NEWMSG) if insert_location == BUFFER_END
        if line[TYPE] == 'action' and username
            pattern = $config.get_pattern('action')
            pattern['%u'] = presence2username(username, false)
            users.push(username)
        elsif username
            pattern = $config.get_pattern('usermessage')
            uname = $config.get_pattern('usernameformat')
            uname = escape_xml(uname)
            uname['%u'] = '<action id="user">'+escape_xml(presence2username(username))+'</action>'
            users.push(username)
        end
        pattern['%m'] = line[MSG].to_s
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_join(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern = $config.get_pattern('join')
        pattern['%u'] = line[PRESENCE]
        users.push(line[PRESENCE])
        pattern['%c'] = line[CHANNEL]
        if user = @users[line[PRESENCE]] and user.hostname
            pattern['%h'] = user.hostname
        else
            pattern['%h'] = line[ADDRESS].to_s
        end
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end    
        
    def buffer_userjoin(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern = $config.get_pattern('userjoin')
        pattern['%c'] = line[CHANNEL]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_part(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern = $config.get_pattern('part')
        pattern['%u'] = line[PRESENCE]
        users.push(line[PRESENCE])
        pattern['%r'] = line[REASON].to_s
        pattern['%c'] = line[CHANNEL]
        if user = @users[line[PRESENCE]] and user.hostname
            pattern['%h'] = user.hostname
        else
            pattern['%h'] = line[ADDRESS].to_s
        end
        pattern = escape_xml(pattern)
       return [uname, pattern, users, insert_location]
    end
    
    def buffer_userpart(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern = $config.get_pattern('userpart')
        pattern['%c'] = line[CHANNEL]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end

    def buffer_error(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern = $config.get_pattern('error')
        pattern['%m'] = line[ERR]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_notice(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern = $config.get_pattern('notice')
        pattern['%m'] = line[MSG]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_topic(line, pattern, uname, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        if line['init'] and line['line'] == 2
            pattern += $config.get_pattern('topic_setby')
            pattern['%c'] = line[CHANNEL]
            pattern['%u'] = line[TOPIC_SET_BY].to_s
            pattern['%a'] = Time.at(line[TOPIC_TIMESTAMP].to_i).strftime('%c')
            users.push(line[TOPIC_SET_BY])
        elsif line['init'] and line['line'] == 1
            pattern += $config.get_pattern('topic')
            pattern['%c'] = line[CHANNEL]
            pattern['%t'] = line[TOPIC]
        elsif line[TOPIC]
            pattern += $config.get_pattern('topic_change')
            pattern['%t'] = line[TOPIC].to_s
            pattern['%u'] = line[TOPIC_SET_BY].to_s
            users.push(line[TOPIC_SET_BY])
        end
        pattern = escape_xml(pattern)
       return [uname, pattern, users, insert_location]
    end
    
    def buffer_modechange(line, pattern, uname, users, insert_location)
        if line[ADD]
            pattern = $config.get_pattern('add_mode')
	    pattern['%m'] = line[ADD]
        elsif line[REMOVE]
            pattern = $config.get_pattern('remove_mode')
	    pattern['%m'] = line[REMOVE]
        else
            return
        end
        pattern['%s'] = line[SOURCE_PRESENCE] if line[SOURCE_PRESENCE]
        #pattern['%m'] = line['mode']
        pattern['%u'] = line[PRESENCE]
        users.push(line[SOURCE_PRESENCE], line[PRESENCE])
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_nickchange(line, pattern, uname, users, insert_location)
        pattern = $config.get_pattern('nickchange')
        
        pattern['%u'] = line[PRESENCE].to_s
        pattern['%n'] = line[NAME].to_s
        
        users.push(line[NAME])
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_usernickchange(line, pattern, uname, users, insert_location)
        pattern = $config.get_pattern('usernickchange')
        
        pattern['%n'] = line[NAME].to_s
        
        users.push(line[NAME])
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
	
	#add a command to the command buffer
	def addcommand(string, increment=true)
		return if string.length == 0
        return if string == @commandbuffer[@commandindex]
        #puts string, @commandbuffer[@commandindex], @commandbuffer[@commandindex-1]
		@commandbuffer.push(string)
		while @commandbuffer.length > $config['commandbuffersize'].to_i
			@commandbuffer.delete_at(0)
		end
		@commandindex += 1 if increment#= @commandbuffer.length
	end
	
	#get the last command in the command buffer
	def getlastcommand
        @commandindex -=1 if @commandindex > 0
        #puts 'back to '+@commandindex.to_s
        command = @commandbuffer[@commandindex]
        command ||= ''
		return command
	end
	
	#get the next command in the command buffer
	def getnextcommand
        @commandindex +=1
        #puts 'forward to '+@commandindex.to_s
		 if @commandindex >= @commandbuffer.length
            @commandindex = @commandbuffer.length if @commandindex > @commandbuffer.length
			return ''
		else
			return @commandbuffer[@commandindex]
		end
	end
    
    def gotolastcommand
        @commandindex = @commandbuffer.length
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
    
    def storedefault
        #get the default color for the text and store it so we can revert to it.
        style = @button.style
        $config.set_value('defaultcolor', style.fg(Gtk::STATE_NORMAL))
    end
	
    #redraw the buttonbox
	def redraw
		if @box != Gtk::VBox and ($config['channellistposition'] == 'right' or $config['channellistposition'] == 'left')
			empty_box
			@box = Gtk::VBox.new
            @box.border_width = 5
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
        
        update_colors
		
		@box.show_all
        renumber
		return @box
	end
	
    #remove all the buttons from a box
	def empty_box
        return unless @box
       # puts @box, @button
		@box.remove(@button)
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
    
    def unnumber(number)
        return unless number
        @tabs.delete_at(number.to_i)
        
        @tabs.each_with_index do |v,i|
            if i >= number.to_i
                v.set_number(i)
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
            channel.update_colors
			insertintobox(channel)
		end
        
		@chats.sort! {|x, y| x.name <=> y.name}
		
		@chats.each do |chat|
            #puts chat.button.label
            chat.update_colors
			insertintobox(chat)
		end
        
        update_colors
        
        @box.show_all
	end
    
    #remove all the buttons from the box
	def empty_box(destroy = true)
        return unless @box
		@box.remove(@button)
		@channels.each do |channel|
			@box.remove(channel.button)
		end
		@chats.each do |chat|
			@box.remove(chat.button)
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
        @parent.renumber
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
                #puts @chat[i].name+' at '+i.to_s
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
            $main.send_command('disconnect'+@name, "presence disconnect;network="+@name+";mypresence="+@presence)
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
            $main.send_command('disconnect'+@name, "presence disconnect;network="+@name+";mypresence="+@presence)
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
        $main.serverlist.unnumber(@number)
        if @connected
            $main.send_command('part', "channel part;network="+@server.name+";mypresence="+@server.presence+";channel="+@name)
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
            $main.send_command('part', "channel part;network="+@server.name+";mypresence="+@server.presence+";channel="+@name)
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
        recolor
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
    include TabCompleteModule
	attr_reader :name, :server, :connected, :users
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
		@users = ChannelUserList.new
        @users.add(@server.users[name])
        @users.add(@server.users[@server.username])
		@connected = nil
        @number = nil
		
		@useriters = []
	end
    
    def set_number(num)
        #return
        @number = num
        if $config['number_tabs']
            md = /^(\d+:).+$/.match(@button.label)
            set_tab_label(@button.label.gsub(md[1], '')) if md
            set_tab_label(@number.to_s+':'+@button.label)
        end
        recolor
    end
    
    def connect
        @connected = true
        @button.show
        @server.chats.sort
        @server.insertintobox(self)
        set_tab_label(@name)
        @server.parent.renumber
        #@server.parent.redraw
    end
    
    def close
        @connected = nil
        $main.serverlist.unnumber(@number)
        @server.removefrombox(@button)
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
    
	def getnetworkpresencepair
		return @server.getnetworkpresencepair
	end
end