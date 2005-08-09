module ReplyParser
    #handle replies from irssi2 (responses to commands sent from a client)
	def reply_parse(reply)
    
        if reply.error
            reply.lines.each do |line|
                if line[REPLY_STATUS] == '-'
                    handle_error(line, reply)
                end
            end
        end
        
		if reply.command['command'] == 'presence status'
			reply_presence_status(reply)
			return
		elsif reply.command['command'] == 'config get'
			$config.parse_config(reply)
			return
		end
		
		reply.lines.each do |line|
			
            channel = nil
            network = nil
            
			if reply.name == 'raw'
				@serverlist.send_user_event({'msg' =>line['original']}, EVENT_NOTICE)
				next
			end
            
            if line[NETWORK] and line[MYPRESENCE]
                if !@serverlist[line[NETWORK], line[MYPRESENCE]]
                else
                    network = @serverlist[line[NETWORK], line[MYPRESENCE]]
                end
                
                if line[CHANNEL] and @serverlist[line[NETWORK], line[MYPRESENCE]]
                    if !@serverlist[line[NETWORK], line[MYPRESENCE]][line[CHANNEL]]
                    else
                        channel = @serverlist[line[NETWORK], line[MYPRESENCE]][line[CHANNEL]]
                    end
                end
            end
            
            begin
                cmd = 'reply_'+reply.command['command'].gsub(' ', '_')
                if self.respond_to?(cmd)
                    res = callback(cmd, line, network, channel, reply)
                    return if res === true
                        self.send(cmd, *res)
                end
            #rescue any exceptions...
            rescue =>exception
                puts 'Error parsing reply : '+$!
                puts exception.backtrace
            end
        end
    end

    #sending a file
    def reply_file_send(line, network, channel, reply)
        if line['handle']
            if line['closed'] and @filehandles[line['handle'].to_i]
                puts 'file sent'
                @filehandles[line['handle'].to_i].close
                @filehandles.delete_at(line['handle'].to_i)
                return
            end
            if reply.command['presence']
                @filehandles[line['handle'].to_i] = @filedescriptors[reply.command['presence']]
            end
            
            file = @filehandles[line['handle'].to_i]
            
            puts line['handle']
            length = line['end'].to_i - line['start'].to_i
            send_command('1', 'file send;handle='+line['handle'], length)
            file.seek(line['start'].to_i)
            data = file.read(length)
            @connection.send(data)
            return
        end
    end
    
    #list the connected presences
    def reply_presence_list(line, network, channel, reply)
        if line[NETWORK] and line[MYPRESENCE]
            unless network = @serverlist[line[NETWORK], line[MYPRESENCE]]
                network = @serverlist.add(line[NETWORK], line[MYPRESENCE])
                if nw = @networks[line[NETWORK]]
                    presence = nw.add_presence(line[MYPRESENCE])
                    presence.autoconnect = true if line[AUTOCONNECT] and presence
                end
            end
            network.set_username(line[PRESENCE] ) if line[PRESENCE]
            if line['connected']
                network.connect
                network.loggedin = true
                @window.redraw_channellist
                switchchannel(network)
            end
        end
        if line[REPLY_STATUS] == '+'
                send_command('channels', "channel list")
        end
        
        i = 0
        @serverlist.servers.each do|server|
            if server.connected
                i += 1
            end
        end
        
        if i == 0
            @window.on_networks1_activate
        end
    end
    
    def reply_network_list(line, network, channel, reply)
        if line[NETWORK] and !@networks[line[NETWORK]]
            @networks.add(line[NETWORK], line[PROTOCOL])
        elsif line[REPLY_STATUS] == '+'
            send_command('gateways', 'gateway list')
        end
    end
    
    def reply_gateway_list(line, network, channel, reply)
        if line[NETWORK] and line[HOST]
            if @networks[line[NETWORK]]
                if line[PORT]
                    network = @networks[line[NETWORK]].add_gateway(line[HOST], line[PORT])
                else
                    network = @networks[line[NETWORK]].add_gateway(line[HOST])
                end
            else
                puts 'unknown network '+line[NETWORK]
            end
        elsif line[REPLY_STATUS] == '+'
            send_command('presences', 'presence list')
        end
    end
    
    def reply_protocol_list(line, network, channel, reply)
        if line[PROTOCOL] and !@protocols[line[PROTOCOL]]
            @protocols.add(line[PROTOCOL], line[CHARSET])
        elsif line[REPLY_STATUS] == '+'
            send_command('networks', 'network list')
        end
    end
    
    #list the connected channels
    def reply_channel_list(line, network, channel, reply)
        if line[NETWORK] and line[MYPRESENCE] and line[CHANNEL]
            if !@serverlist[line[NETWORK], line[MYPRESENCE]]
                puts 'network does not exist '+line[NETWORK]+', '+line[MYPRESENCE]
            else
                unless channel = @serverlist[line[NETWORK], line[MYPRESENCE]][line[CHANNEL]]
                    channel = @serverlist[line[NETWORK], line[MYPRESENCE]].add(line[CHANNEL])
                end
                
                if line['joined'] and channel
                    if line[TOPIC]
                        channel.topic = line[TOPIC]
                    end
                    channel.connect
                    switchchannel(channel)
                end
            end
        
        elsif line[REPLY_STATUS] == '+'
            syncchannels
        end
        
    end
    
    #list of users on the channel
    def reply_channel_names(line, network, channel, reply)
        if line[NETWORK] and line[MYPRESENCE] and line[CHANNEL] and line[PRESENCE]
            network.users.create(line[PRESENCE])
            chuser = channel.users.add(network.users[line[PRESENCE]])
            if line['mode'] and chuser
                chuser.add_mode(line['mode'])
            end
        elsif line[REPLY_STATUS] == '+'
            @serverlist[reply.command['network'], reply.command['mypresence']][reply.command['channel']].drawusers
            @window.updateusercount
            @serverlist[reply.command['network'], reply.command['mypresence']][reply.command['channel']].usersync = true
        end
    end

    #handle past events here
    def reply_event_get(line, network, channel, reply)
        reply.network ||= network if network
        reply.channel ||= channel if channel
        if line[EVENT] == 'msg'
            if line[ADDRESS] and network.users[line[PRESENCE]] and network.users[line[PRESENCE]].hostname == 'hostname'
                network.users[line[PRESENCE]].hostname = line[ADDRESS]
            end
                
            if line[OWN]
		#I don't know why I did this, but I'm fixing something else ATM so 'll come back to it
                line[PRESENCE] = network.username #line[MYPRESENCE]
                channel.send_event(line, EVENT_USERMESSAGE, BUFFER_START)
            else
                channel.send_event(line, EVENT_MESSAGE, BUFFER_START)
            end
            
        elsif line[EVENT] == 'channel_changed'
            if line[TOPIC] and line['init']
                #send the topic stuff as 2 lines
                channel.topic = line[TOPIC]
                line['line'] = 2
                channel.send_event(line, EVENT_TOPIC, BUFFER_START)
                line['line'] = 1
                channel.send_event(line, EVENT_TOPIC, BUFFER_START)
                @window.updatetopic
            elsif line[TOPIC]
                channel.topic = line[TOPIC]
                channel.send_event(line, EVENT_TOPIC, BUFFER_START)
                @window.updatetopic
            end
            
        elsif line[EVENT] == 'presence_changed'
            #this doesn't seem to be reached, ever
            if line[NAME]
                if event[NAME] == network.username
                    type = EVENT_USERNICKCHANGE
                else
                    type = EVENT_NICKCHANGE
                end
                
                if type
                    network.channels.each do |c|
                        if c.users[event[NAME]]
                            c.drawusers
                            c.send_event(event, type, BUFFER_START)
                        end
                    end
                end
            end
            
        elsif line[EVENT] == 'channel_presence_removed'
            return if line['deinit']
            
            if line[PRESENCE] == network.username
                channel.send_event(line, EVENT_USERPART, BUFFER_START)
            else
                channel.send_event(line, EVENT_PART, BUFFER_START)
            end
        
        elsif line[EVENT] == 'channel_part'
            channel.send_event(line, EVENT_USERPART, BUFFER_START)
            
        elsif line[EVENT] == 'channel_join'
            channel.send_event(line, EVENT_USERJOIN, BUFFER_START)
            
        elsif line[EVENT] == 'channel_presence_added'
            return if line['init']
            
            if line[PRESENCE] == network.username
                channel.send_event(line, EVENT_USERJOIN, BUFFER_START)
            else
                channel.send_event(line, EVENT_JOIN, BUFFER_START)
            end
            
        #~ elsif line[EVENT] == 'irc_ctcp'
            #~ puts 'CTCP', line['original']
        
            #~ if line['name'] == 'action' and line['args']
                #~ puts 'action'
                #~ channel.send_event(line, CTCP, BUFFER_START)
            #~ end
            
        elsif line[REPLY_STATUS] == '+'
            reply.channel.eventsync = true if reply.channel
        end
    end
    
	#output the result of a whois
	def reply_presence_status(reply)
		network = @serverlist[reply.command['network'], reply.command['mypresence']]
		
		reply.lines.each do |line|
		
			if line[ADDRESS] and line['real_name']
				msg = '('+line[ADDRESS]+') : '+line['real_name']
			elsif line[ADDRESS]
				address = line[ADDRESS]
				next
			elsif line['real_name'] and address
				msg = address+' : '+line['real_name']
			elsif line['server_address'] and line['server_name']
				msg = line['server_address']+' : '+line['server_name']
			elsif line['idle'] and line['login_time']
				idletime = duration(line['idle'].to_i)
				logintime = duration(Time.at(line[TIME].to_i) - Time.at(line['login_time'].to_i))
				msg = 'Idle: '+idletime+' -- Logged on: '+Time.at(line['login_time'].to_i).strftime('%c')+' ('+logintime+')'
			elsif line['channels']
				msg = line['channels']
			elsif line['extra']
				msg = line['extra']
			elsif line[REPLY_STATUS] == '+'
				msg = 'End of /whois'
				line[PRESENCE] = reply.command['presence']
			else
				next
			end
			
			pattern = $config['whois'].deep_clone
			pattern['%m'] = msg if msg
			pattern['%n'] = line[PRESENCE] if line[PRESENCE]
			line['msg'] = pattern
			network.send_event(line, EVENT_NOTICE)
			time = line[TIME]
		end
	end

end