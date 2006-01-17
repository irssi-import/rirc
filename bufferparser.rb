module BufferParser
    #send an event from the user to the buffer
    def send_user_event(line, type)
         unless @buffer
            puts 'not connected'
            return
        end       
        x = Line.new
        
        line.each do |k,v|
            x[k.to_sym] = v
        end
        
        line = x
        time = Time.new
        time = time - @window.main.drift if @config['canonicaltime'] == 'server'
        line[TIME] = time
        line[ID] = 'client'+rand(1000).to_s
        while @buffer.has_id? line[ID]
            line[ID] = 'client'+rand(1000).to_s
        end
        send_event(line, type)
    end
    
    #send a line to the buffer
    def send_event(line, type, insert_location=BUFFER_END)
        #return if !@connected
        unless @buffer
            puts 'not connected'
            return
        end
        
        if @buffer.has_id? line[ID]
#             puts line[ID]
#             puts @buffer.has_id?(line[ID])
#             puts 'event already in buffer'
            return
        end
        
        raise ArgumentError unless line.class == Line
        
        pattern = ''
        
        uname = ''
		
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
		
        unless pattern.nil?
            if insert_location == BUFFER_START
                return @buffer.prepend([line[TIME].to_i, parse_tags(uname), parse_tags(pattern)], line[ID])
            elsif insert_location == BUFFER_END
                return @buffer.append([line[TIME].to_i, parse_tags(uname), parse_tags(pattern)], line[ID])
            end
        end
        
    end
    
    def marklastread
        @buffer.marklastread
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
                attributes = 'foreground="'+@config['color'+colorid].to_hex+'"'
                
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
        
        md = HYPERLINKREGEXP.match(string)
		
        while md.class == MatchData
            if md[0].scan('.').size >= 2 or md[0].scan('://').size > 0
                #links.push(md[0])
                string.sub!(md[0], '<action id="url">'+md[0]+'</action>')
            end
            md = HYPERLINKREGEXP.match(md.post_match)
	end
        
        return string
    end
    
    def presence2username(name, padding=true)
        return name unless @config['show_usermode']
        if self.class == ChannelBuffer
            if @users.include?(name)
                user = @users[name]
                mode = user.mode_symbol
                mode = ' ' if mode =='' and padding and @config['pad_usermode']
                return mode+name
            end
        end
        return name
    end
    
    def buffer_message(line, pattern, uname, users, insert_location)
        set_status(NEWMSG) if insert_location == BUFFER_END
        if line[TYPE] == 'action' and line[PRESENCE]
            pattern = @config.get_pattern('action')
            pattern['%u'] = presence2username(line[PRESENCE], false)
            if line[MSG_XHTML]
                pattern = escape_xml(pattern)
                pattern['%m'] = xhtml_im2pango(line[MSG_XHTML])
            else
                pattern['%m'] = line[MSG].to_s
                pattern = escape_xml(pattern)
            end
        else
            pattern = @config.get_pattern('message')
            if line[PRESENCE]
                uname = @config.get_pattern('otherusernameformat')
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
        set_status(NEWMSG) if insert_location == BUFFER_END
        if line[TYPE] == 'action' and username
            pattern = @config.get_pattern('action')
            pattern['%u'] = presence2username(username, false)
            users.push(username)
        elsif username
            pattern = @config.get_pattern('usermessage')
            uname = @config.get_pattern('usernameformat')
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
        return true if @config['dropjoinpart']
        set_status(NEWDATA) if insert_location == BUFFER_END
        pattern = @config.get_pattern('join')
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
        set_status(NEWDATA) if insert_location == BUFFER_END
        pattern = @config.get_pattern('userjoin')
        pattern['%c'] = line[CHANNEL]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_part(line, pattern, uname, users, insert_location)
        return true if @config['dropjoinpart']
        set_status(NEWDATA) if insert_location == BUFFER_END
        pattern = @config.get_pattern('part')
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
        set_status(NEWDATA) if insert_location == BUFFER_END
        pattern = @config.get_pattern('userpart')
        pattern['%c'] = line[CHANNEL]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end

    def buffer_error(line, pattern, uname, users, insert_location)
        set_status(NEWDATA) if insert_location == BUFFER_END
        pattern = @config.get_pattern('error')
        pattern['%m'] = line[ERR]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_notice(line, pattern, uname, users, insert_location)
        set_status(NEWDATA) if insert_location == BUFFER_END
        pattern = @config.get_pattern('notice')
        pattern['%m'] = line[MSG]
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_topic(line, pattern, uname, users, insert_location)
        set_status(NEWDATA) if insert_location == BUFFER_END
        if line['init'] and line['line'] == 2
            pattern += @config.get_pattern('topic_setby')
            pattern['%c'] = line[CHANNEL]
            pattern['%u'] = line[TOPIC_SET_BY].to_s
            pattern['%a'] = Time.at(line[TOPIC_TIMESTAMP].to_i).strftime('%c')
            users.push(line[TOPIC_SET_BY])
        elsif line['init'] and line['line'] == 1
            pattern += @config.get_pattern('topic')
            pattern['%c'] = line[CHANNEL]
            pattern['%t'] = line[TOPIC]
        elsif line[TOPIC]
            pattern += @config.get_pattern('topic_change')
            pattern['%t'] = line[TOPIC].to_s
            pattern['%u'] = line[TOPIC_SET_BY].to_s
            users.push(line[TOPIC_SET_BY])
        end
        pattern = escape_xml(pattern)
       return [uname, pattern, users, insert_location]
    end
    
    def buffer_modechange(line, pattern, uname, users, insert_location)
        if line[ADD]
            pattern = @config.get_pattern('add_mode')
	    pattern['%m'] = line[ADD]
        elsif line[REMOVE]
            pattern = @config.get_pattern('remove_mode')
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
        pattern = @config.get_pattern('nickchange')
        
        pattern['%u'] = line[PRESENCE].to_s
        pattern['%n'] = line[NAME].to_s
        
        users.push(line[NAME])
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
    
    def buffer_usernickchange(line, pattern, uname, users, insert_location)
        pattern = @config.get_pattern('usernickchange')
        
        pattern['%n'] = line[NAME].to_s
        
        users.push(line[NAME])
        pattern = escape_xml(pattern)
        return [uname, pattern, users, insert_location]
    end
end
