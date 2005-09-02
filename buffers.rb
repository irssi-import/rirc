class Buffer
	attr_reader :oldendmark, :currentcommand, :buffer, :button, :links
	attr_writer :currentcommand
    extend Plugins
    include PluginAPI
	def initialize(name)
		@buffer = Gtk::TextBuffer.new
        
        #TODO italics...?
        @links = []
        @buffer.create_tag('bold', {'weight' =>  Pango::FontDescription::WEIGHT_BOLD})
        @buffer.create_tag('underline', {'underline' => Pango::AttrUnderline::SINGLE})
		@commandbuffer = []
		@currentcommand = ''
		@commandindex = 0
		@button = Gtk::ToggleButton.new(name)
		@button.active = false
		@togglehandler = @button.signal_connect('toggled')do |w|
			switchchannel(self)
		end
        
        update_colors
        
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
        16.times do |x|
            if $config['color'+x.to_s] and tag = @buffer.tag_table.lookup('color'+x.to_s)
                #puts 'updating '+tag.to_s
                tag.foreground_gdk = $config['color'+x.to_s]
            elsif $config['color'+x.to_s] 
                @buffer.create_tag('color'+x.to_s, {'foreground_gdk'=>$config['color'+x.to_s]}) if $config['color'+x.to_s]
            end
        end
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
			insert = @buffer.end_iter
            @linebuffer.push(line)
		elsif insert_location == BUFFER_START
			insert = @buffer.start_iter
            @linebuffer.unshift(line)
		end
		
		if $config['usetimestamp']
            re = /((%%(C[0-9]{1}[0-5]*|U|B|I)).*\2)/
            
            timestamp = $config['timestamp'].deep_clone
            
            md = re.match(timestamp)
            
            while md.class == MatchData
                text = md[1].gsub(md[2], '^^'+md[3])
                timestamp.gsub!(md[1], text)
                
                md = re.match(timestamp)
            end
                    
        
			pattern = Time.at(line[TIME].to_i).strftime(timestamp)
            
            pattern.gsub!(/(\^\^(C[0-9]{1}[0-5]*|U|B|I))/){|s| '%'+$2}
		else
			pattern = ''
		end
        
        if line[MSG]
            re= %r{((((http|ftp|irc|https)://|)([\w\-]+\.)+[a-zA-Z]{2,4}|(\d{1,3}\.){3}(\d{1,3}))([.\/]{1}[^\s\n\(\)\[\]\r]+|))}
            md = re.match(line[MSG])
            
            while md.class == MatchData
                if md[0].scan('.').size >= 2 or md[0].scan('://').size > 0
                    dup = false
                    @links.each_with_index do |link, index|
                        next if dup == true
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
		
		@oldlineend = @buffer.end_iter
		@oldendmark = @buffer.create_mark('oldend', @buffer.end_iter, true)
        
        local = self
        
        begin
            cmd = 'buffer_'+type
            if self.respond_to?(cmd)
                res = callback(cmd, line, pattern, users, insert_location)
                return if res === true
                res2 = self.send(cmd, *res)
                pattern, users, insert_location = callback_after(cmd, *res2)
            else
                return
            end
        #rescue any exceptions...
        rescue =>exception
            puts 'Error sending : '+$!
            puts exception.backtrace
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
			colortext(pattern, insert, users, line[ID])
		end
		
		@newlineend = @buffer.end_iter
		
		$main.scroll_to_end(self)
			
	end
    
    def get_last_line_id(user)
        @linebuffer.reverse_each do |line|
            if line[PRESENCE] == user
                return line[ID]
            end
        end
        
        return nil
    end
    
    def get_line_by_id(id)
        #gets the start and stop marks for a line in the buffer
        return unless id
        
        start = @buffer.get_mark(id+'_start')
        stop = @buffer.get_mark(id+'_end')
        
        return [start, stop]
    end
    
    def remove_line(start, stop)
        #remove the line between start and stop marks, returns true if line is at the end
        return unless start and stop
        
        puts @buffer.get_text(@buffer.get_iter_at_mark(start), @buffer.get_iter_at_mark(stop))
        
        @buffer.delete(@buffer.get_iter_at_mark(start), @buffer.get_iter_at_mark(stop))
        
        if @buffer.get_iter_at_mark(stop).offset == @buffer.end_iter.offset
            iter = @buffer.get_iter_at_mark(start)
            iter.offset += 1
            @buffer.delete(iter, @buffer.end_iter)
            return true
        else
            @buffer.delete(@buffer.get_iter_at_mark(start), @buffer.get_iter_at_mark(stop))
        end
            
    end
    
    def replace_line(id, replacement)
        #replaces a line in the buffer
        start, stop = get_line_by_id(id)
        
        return unless start and stop
    
        if remove_line(start, stop)
            replacement += "\n"
        end
        
        @buffer.insert(@buffer.get_iter_at_mark(start), replacement)
    end
    
    def delete_line(id)
        #deletes a line in the buffer
        start, stop = get_line_by_id(id)
        
        return unless start and stop
    
        remove_line(start, stop)
        
        @buffer.delete_mark(start)
        @buffer.delete_mark(stop)
    end
    
    def buffer_message(line, pattern, users, insert_location)
        setstatus(NEWMSG) if insert_location == BUFFER_END
        if line[TYPE] == 'action' and line[PRESENCE]
            pattern += $config.get_pattern('action')
            pattern['%u'] = line[PRESENCE]
            if line[MSG_XHTML]
                pattern = escape_xml(pattern)
                pattern['%m'] = line[MSG_XHTML]
            else
                pattern['%m'] = line[MSG].to_s
                pattern = escape_xml(pattern)
            end
        else
            pattern += $config.get_pattern('message')
            if line[PRESENCE]
                pattern['%u'] = line[PRESENCE]
                users.push(line[PRESENCE])
            end
            if line[MSG_XHTML]
                pattern = escape_xml(pattern)
                pattern['%m'] = line[MSG_XHTML]
            elsif line[MSG]
                pattern['%m'] = line[MSG]
                pattern = escape_xml(pattern)
            else
                pattern = escape_xml(pattern)
            end
        end
        return [pattern, users, insert_location]
    end
    
    def buffer_usermessage(line, pattern, users, insert_location)
        setstatus(NEWMSG) if insert_location == BUFFER_END
        if line[TYPE] == 'action' and username
            pattern += $config.get_pattern('action')
            pattern['%u'] = username
            users.push(username)
        elsif username
            pattern += $config.get_pattern('usermessage')
            pattern['%u'] = username
            users.push(username)
        end
        pattern['%m'] = line[MSG].to_s
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def buffer_join(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config.get_pattern('join')
        pattern['%u'] = line[PRESENCE]
        users.push(line[PRESENCE])
        pattern['%c'] = line[CHANNEL]
        if user = @users[line[PRESENCE]] and user.hostname
            pattern['%h'] = user.hostname
        else
            pattern['%h'] = line[ADDRESS].to_s
        end
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end    
        
    def buffer_userjoin(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config.get_pattern('userjoin')
        pattern['%c'] = line[CHANNEL]
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def buffer_part(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config.get_pattern('part')
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
       return [pattern, users, insert_location]
    end
    
    def buffer_userpart(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config.get_pattern('userpart')
        pattern['%c'] = line[CHANNEL]
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end

    def buffer_error(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config.get_pattern('error')
        pattern['%m'] = line[ERR]
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def buffer_notice(line, pattern, users, insert_location)
        setstatus(NEWDATA) if insert_location == BUFFER_END
        pattern += $config.get_pattern('notice')
        pattern['%m'] = line[MSG]
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def buffer_topic(line, pattern, users, insert_location)
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
       return [pattern, users, insert_location]
    end
    
    def buffer_modechange(line, pattern, users, insert_location)
        if line[ADD]
            pattern += $config.get_pattern('add_mode')
	    pattern['%m'] = line[ADD]
        elsif line[REMOVE]
            pattern += $config.get_pattern('remove_mode')
	    pattern['%m'] = line[REMOVE]
        else
            return
        end
        pattern['%s'] = line[SOURCE_PRESENCE] if line[SOURCE_PRESENCE]
        #pattern['%m'] = line['mode']
        pattern['%u'] = line[PRESENCE]
        users.push(line[SOURCE_PRESENCE], line[PRESENCE])
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def buffer_nickchange(line, pattern, users, insert_location)
        pattern += $config.get_pattern('nickchange')
        
        pattern['%u'] = line[PRESENCE].to_s
        pattern['%n'] = line[NAME].to_s
        
        users.push(line[NAME])
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def buffer_usernickchange(line, pattern, users, insert_location)
        pattern += $config.get_pattern('usernickchange')
        
        pattern['%n'] = line[NAME].to_s
        
        users.push(line[NAME])
        pattern = escape_xml(pattern)
        return [pattern, users, insert_location]
    end
    
    def endmark
        return @buffer.create_mark('end', @buffer.end_iter, true)
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
	
	#parse the colors in the text
    #TODO - Do we need to make this support nested tags?
	def colortext(string, insert, users, id)
        
        #parse it for XHTML-IM tags
        string, tags = parse_xml(string)
        
        re = /((%(C[0-9]{1}[0-5]*|U|B|I)).+?\2)/
		md = re.match(string)
		
		while md.class == MatchData
            
            tag = nil
            
            if md[2] =~ /^%C[0-9]{1}[0-5]*$/
                tag = md[2].gsub!('%C', 'color')
                colorid = md[2].gsub!('%C', '')
                
            elsif md[2] == '%U'
                tag = 'underline'
                
            elsif md[2] == '%B'
                tag = 'bold'
                
            elsif md[2] == '%I'
                tag = 'italic'
            end
            
            #remove the tags from the text
            text = md[0].gsub(md[2], '')
    
            #strip the tags for this tag from the string
            #for some reason []= fucked up for some people, sub is probably better anyway
            string.sub!(md[1], text)
            
            if tag
                #create a tag with a range
                start, stop = md.offset(1)
                stop -= (md[2].length)*2
                tags[Range.new(start, stop)] = tag
            end
			
			#go around again
			md = re.match(string)
		end
        
        #strip out any empty patterns
        re = /((%(C[0-9]{1}[0-5]*|U|B|I))\2)/
        md = re.match(string)
        while md.class == MatchData
            string.sub!(md[0], '')
            md = re.match(string)
        end
		
		links = []
		
		#re = %r{(([a-zA-Z]+\://|[\w\-]+\.)[\w.\-]+\.[\w.\-,]+([^\s\n\(\)\[\]\r]+|))}
        re= %r{((((http|ftp|irc|https)://|)([\w\-]+\.)+[a-zA-Z]{2,4}|(\d{1,3}\.){3}(\d{1,3}))([.\/]{1}[^\s\n\(\)\[\]\r]+|))}
		md = re.match(string)
		
		while md.class == MatchData
            if md[0].scan('.').size >= 2 or md[0].scan('://').size > 0
                links.push(md[0])
            end
			md = re.match(md.post_match)
		end
		
		user_tags = {}
		link_tags = {}
		
		users.each do |user|
            next unless user
			if index = string.index(user)
				user_tags[Range.new(index, index+user.length)] = user
			end
		end
		
		links.each do |link|
			if index = string.index(link)
				link_tags[Range.new(index, index+link.length)] = link
			end
		end
        
		sendtobuffer(string, tags, insert, user_tags, link_tags, id)
	end
    
    #parse xhtml-im styles into tags
    def get_tag(key, value)
        if key == 'color'
            
            value.gsub!('\'', '')
            #if we already have the color in a tag, use it
            if @buffer.tag_table.lookup('color_'+value)
                return 'color_'+value
            end
            
            re = Regexp.new('#[a-fA-F0-9]+')
            
            #if color is a hex value, and its not fully padded, try to pad it
            while value =~ re and value.length < 7
                value['#'] = '#0'
            end
            
            #pass the color to GDK, and catch the exception if its invalid
            begin
                color = Gdk::Color.parse(value)
            rescue ArgumentError
                $main.throw_error('Invalid color '+value)
                return '0'
            end
            
            #assuming everything worked out, create the color tag
            @buffer.create_tag('color_'+value, {'foreground_gdk'=>color})
            return 'color_'+value
        
        #handle the 'bold' font weight
        elsif key == 'font-weight'
            if value == 'bold'
                return 'bold'
            end
        
        #handle 'underline'
        elsif key == 'text-decoration'
            if value == 'underline'
                return 'underline'
            end
        end
    end
    
    #split up xhtml-im styles into their components
    def parse_style(style)
        styles = style.split(';')
        tags = []
        styles.each do |x|
            k, v = x.split(':').map{|e| e.strip.downcase}
            tags.push(get_tag(k, v))
        end
        return tags
    end
    
    #parse xhtml-im strings
    def parse_xml(istring)
        #add some root tags around the string to keep Rexml happy
        doc = REXML::Document.new('<msg>'+istring+'</msg>')
        string = ''
        tags = {}
        x = doc.root[0]
        
        #loop through the tags
        #TODO - maybe this should handle children of children...?
        while x
        
            #hey look, its a text node, we just append it to the result string
            if x.class == REXML::Text
                string += x.value
            
            #its a xml element, do some stuff
            elsif x.class == REXML::Element
            
                #check if it has style
                if x.attributes['style']
                
                    #do some magic to account for the % color tags in the string in the tag offsets
                    offset = 0
                    #regular expression to match color tags
                    re = Regexp.new('((%(C[0-9]{1}[0-5]*|U|B|I)).?\2)')
                    #scan the string and update the offset value
                    string.scan(re){|z| offset += ($2.length)*2 if $2}
                    #get the start and stop values
                    start = string.length-offset
                    
                    if x.text
                        stop = x.text.length+start
                        #append the string
                        string += x.text
                    else
                        stop = start
                    end
                    
                    #get any tags derived from the style
                    taglist = parse_style(x.attributes['style'])
                    
                    #bundle all the tags up nicely
                    taglist.each do |tag|
                        tags[Range.new(start, stop)] = tag
                    end
                end
            end
            
            #go around again
            x = x.next_sibling
        end
        
        #not sure, worst case fallback?
        if string == ''
            string = istring
        end
        
        return [string, tags]
    end
	
	#send the text to the buffer
	def sendtobuffer(string, tags, insert, user_tags, link_tags, id)
		offset = insert.offset
		@buffer.insert(insert, string)
		iter = @buffer.get_iter_at_offset(offset)
        #puts id
        @buffer.create_mark(id+'_start', iter, false)
        iter = @buffer.get_iter_at_offset(offset)
		start = iter.offset
		tags.each do |k, v|
			if v and @buffer.tag_table.lookup(v)
				tag_start = @buffer.get_iter_at_offset(k.begin+start)
				tag_end = @buffer.get_iter_at_offset(k.end+start)
				@buffer.apply_tag(v, tag_start, tag_end)
			else
				puts 'invalid tag '+v.to_s
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
        
        iter = @buffer.get_iter_at_offset(offset+string.length)
        @buffer.create_mark(id+'_end', iter, true)
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
        $main.serverlist.unnumber(@number)
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
    
	def getnetworkpresencepair
		return @server.getnetworkpresencepair
	end
end