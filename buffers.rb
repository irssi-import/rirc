class Buffer
    attr_reader :oldendmark, :currentcommand, :liststore, :links, :view
    attr_writer :currentcommand
    #extend Plugins
    include PluginAPI
	def initialize(name)
        @links = []

        @view = BufferView.new
        #@ids = {}
        
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
        
        @linebuffer = []

        @modes = ['message', 'usermessage', 'join', 'userjoin', 'part', 'userpart', 'error', 'notice', 'topic', 'modechange', 'ctcp']
	end
    
    def rightclickmenu(event)
        puts 'popping up menu'
        menu = genmenu
        return unless menu
        menu.show_all
        menu.popup(nil, nil, event.button, event.time)
        return true
    end
    
    def genmenu
        return nil
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
	
    #disconnect a channel
	def disconnect
        #puts caller
		#~ set_tab_label('('+@name+')')
        #~ if $config['number_tabs'] and @number
            #~ set_tab_label(@number.to_s+':'+@button.label)
        #~ end
        @connected = false unless @connected.nil?
	end
	
    #reconnect a channel
	def reconnect
		#~ set_tab_label(@name)
        #~ if $config['number_tabs'] and @number
            #~ set_tab_label(@number.to_s+':'+@button.label)
        #~ end
		@connected = true
	end
    
    #update the status of a channel
	def setstatus(status)
        #puts 'requesting setting of status of '+@name+' to '+status.to_s
        $main.tabmodel.setstatus(self, status)
		#~ if(status > @status)
			#~ @status = status
			#~ recolor
		#~ end
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
        line[ID] = 'client'+rand(1000).to_s
        while @view.has_id? line[ID]
            line[ID] = 'client'+rand(1000).to_s
        end
        send_event(line, type)
    end
    
    #send a line to the buffer
	def send_event(line, type, insert_location=BUFFER_END)
		return if !@connected
        
        if @view.has_id? line[ID]
            puts line[ID]
            puts @view.has_id?(line[ID])
            puts 'event already in buffer'
            return
        end
        
        raise ArgumentError unless line.class == Line
		
		#~ if insert_location == BUFFER_END
			#~ #insert = @buffer.end_iter
            #~ @linebuffer.push(line)
		#~ elsif insert_location == BUFFER_START
			#~ #insert = @buffer.start_iter
            #~ @linebuffer.unshift(line)
		#~ end
        
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
                return if res2 === true
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
		
		unless pattern.nil?
			#recolor
			if insert_location == BUFFER_START
                #iter = @liststore.prepend
                return @view.prepend([line[TIME].to_i, parse_tags(uname), parse_tags(pattern)], line[ID])
			elsif insert_location == BUFFER_END
                #iter = @liststore.append
                return @view.append([line[TIME].to_i, parse_tags(uname), parse_tags(pattern)], line[ID])
			end
            #iter[0] = line[TIME].to_i
            #iter[1] = parse_tags(uname)
            #iter[2] = parse_tags(pattern)
            #@ids[line[ID]] = Gtk::TreeRowReference.new(@liststore, iter.path)
            #puts @ids[line[ID]]
            #if insert_location == BUFFER_END
            #    @last = @view.lines[line[ID]]
            #    marklastread unless @lastread
            #end
            #trim
		end
			
	end
    
    #~ def trim
        #~ return unless @ids.length > 200
        #~ lines = @ids.sort{|x, y| x.path <=> y.path}
        #~ while lines.length > 200
            #~ puts lines[0]
            #~ iter = lines.shift
            #~ @liststore.remove(iter)
            #~ puts "Trimming #{iter.path}"
        #~ end
        #~ (@ids.length-200).times do |x|
            #~ @liststore.remove(@liststore.iter_first)
            #~ #puts 'trimming'
        #~ end
        #~ @ids = Hash[*@ids.select{|x, y| y.nil? or y.valid?}.flatten]
        
    #~ end
    
    def marklastread
        @view.marklastread
        #~ return unless @last
        #~ #puts 'marking line '+@last.path
        #~ iter = @liststore.get_iter(@last.path)
        
        #~ begin
        #~ if @lastread and @lastread.valid?
            #~ iter2 = @liststore.get_iter(@lastread.path)
            #~ iter2[3] = ''
        #~ end
        #~ rescue ArgumentError
            #~ puts @lastread, @lastread.valid?
        #~ end
        
        #~ iter[3] = $config['scw_lastread'].to_hex
        
        #~ @lastread = @last
    end
    
    def xhtml_im2pango(string)
        return unless string
        #puts string
        re = /\<span style=[\"\'](.+?)[\"\']\>([^\<]+)\<\/span\>/i
        md = re.match(string)
        
        while md.class == MatchData
            x = parse_style(md[1])
            
            replacement = '<s '+x+'>'+md[2]+'</s>'
            
            string.sub!(md[0], replacement)
            
            md = re.match(string)
        end
        
        return string.gsub('<s ', '<span ').gsub('</s>', '</span>')
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
            #puts attribute, value, style
            result.push(attribute+'="'+value+'"') if attribute and value
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
                #uname['%u'] = presence2username(line[PRESENCE])
                users.push(line[PRESENCE])
            end
            if line[MSG_XHTML]
                pattern = escape_xml(pattern)
                pattern['%m'] = xhtml_im2pango(line[MSG_XHTML])
            else
                pattern['%m'] = line[MSG].to_s
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
            #uname['%u'] = presence2username(username)
            users.push(username)
        end
        pattern['%m'] = line[MSG].to_s
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_join(line, pattern, uname, users, insert_location)
        return true if $config['dropjoinpart']
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
        return true if $config['dropjoinpart']
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
        if line[SOURCE_PRESENCE]
            pattern['%s'] = line[SOURCE_PRESENCE]
        elsif line[:irc_source_nick]
            pattern['%s'] = line[:irc_source_nick]
        end
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
    #TODO ditch the parent?
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
        
        #redraw
	end
    
    def storedefault
        #get the default color for the text and store it so we can revert to it.
        #~ style = @button.style
        #~ $config.set_value('defaultcolor', style.fg(Gtk::STATE_NORMAL))
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
            #$main.tabmodel.add(newserver)
			#insertintobox(newserver)
			return newserver
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
    
end

#buffer used for networks
class ServerBuffer < Buffer
	attr_reader :name, :channels, :box, :parent, :config, :username, :presence, :connected, :users, :server, :chats, :loggedin, :bufferedcommands
    attr_writer :bufferedcommands, :loggedin
	def initialize(name, presence, parent)
		super(name)
        @server = self
		@presence = presence
		@username = @presence.dup
		@parent = parent
		@name = name
		@channels = Array.new
		@chats = Array.new
		@users = UserList.new
		#~ if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
			#~ @box = Gtk::VBox.new
		#~ else
			#~ @box = Gtk::HBox.new
		#~ end
		#~ @box.pack_start(@button, false, false)
		#~ @box.show
		#@status = INACTIVE
		#if($config.serverbuttons)
		#end
		@connected = nil
        @loggedin = false
        @bufferedcommands = []
	end
	
    def connect
        #puts 'connected '+@name
        @connected = true
        $main.tabmodel.add(self)
        #@parent.redraw
    end
    
    def reconnect
        super
        @loggedin = false
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
        #$main.tabmodel.add(newchannel)
		#insertintobox(newchannel)
        #@parent.renumber
		return newchannel
	end
	
    #add a chat to the network
	def addchat(name)
        if newchat = has_chat?(name)
            return newchat
        end
		newchat = ChatBuffer.new(name, self)
		@chats.push(newchat)
		@chats.sort! {|x, y| x.name <=> y.name}
		#insertintobox(newchat)
        #@parent.renumber
		return newchat
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
        #puts 'no chat for '+name
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
        $main.tabmodel.remove(self)
        #set_tab_label(@name)
        #@server.removefrombox(@button)
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
		#set_tab_label(@name)
		#@button.show
		@users = ChannelUserList.new
		@connected = nil
        @number = nil
		
		@useriters = []
	end
    
    def connect
        @connected = true
        $main.tabmodel.add(self)
        #@server.channels.sort
        #@server.channels.each {|channel| puts channel.name unless channel.connected.nil?}
        #@server.insertintobox(self)
        #set_tab_label(@name)
        #@server.parent.renumber
        #@server.parent.redraw
        #server.redraw
    end
    
    def close
#        $main.serverlist.unnumber(@number)
        if @connected
            $main.send_command('part', "channel part;network="+@server.name+";mypresence="+@server.presence+";channel="+@name)
        end
        @connected = nil
        @number = nil
        $main.tabmodel.remove(self)
        #@button.label = @name.gsub('_', '__')
        #set_tab_label(@name)
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
        #~ @number = num
        #~ if $config['number_tabs']
            #~ md = /^(\d+:).+$/.match(@button.label)
            #~ set_tab_label(@button.label.gsub(md[1], '')) if md
            #~ set_tab_label(@number.to_s+':'+@button.label)
        #~ end
        #~ recolor
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
		#set_tab_label(@name)
		#@button.active = false
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
        #~ @number = num
        #~ if $config['number_tabs']
            #~ md = /^(\d+:).+$/.match(@button.label)
            #~ set_tab_label(@button.label.gsub(md[1], '')) if md
            #~ set_tab_label(@number.to_s+':'+@button.label)
        #~ end
        #~ recolor
    end
    
    def connect
        @connected = true
        $main.tabmodel.add(self)
        #@button.show
        #@server.chats.sort
        #@server.insertintobox(self)
        #set_tab_label(@name)
        #@server.parent.renumber
        #@server.parent.redraw
    end
    
    def close
        @connected = nil
        $main.tabmodel.remove(self)
        #$main.serverlist.unnumber(@number)
        #@server.removefrombox(@button)
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
        #set_tab_label(name)
    end
    
	def getnetworkpresencepair
		return @server.getnetworkpresencepair
	end
end