module ReplyParser
    #handle replies from irssi2 (responses to commands sent from a client)
	def reply_parse(reply)
    
        if reply.error
            reply.lines.each do |line|
                if line['reply_status'] == '-'
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
				output = {}
				output['msg'] =  line['original']
				@serverlist.send_event(output, NOTICE)
				next
			end
			
			#if line['status'] == '-'
				#line['err'] = 'Error: '+line['error']+' encountered when sending command '+reply.origcommand
				#@serverlist.send_event(line, ERROR)
				#return
			#end
            
            if line['network'] and line['presence']
                if !@serverlist[line['network'], line['presence']]
                else
                    network = @serverlist[line['network'], line['presence']]
                end
                
                if line['channel'] and @serverlist[line['network'], line['presence']]
                    if !@serverlist[line['network'], line['presence']][line['channel']]
                    else
                        channel = @serverlist[line['network'], line['presence']][line['channel']]
                    end
                end
            end
            
            cmd = 'reply_'+reply.command['command'].gsub(' ', '_')
            if self.respond_to?(cmd)
                res = callback(cmd, line, network, channel, reply)
                return if res === true
                #if res.class == Array and res.length > 0
                    self.send(cmd, *res)
                #else
                #    self.send(cmd, line, network, channel, reply)
                #end
            end
        end
    end

    #sending a file
    def reply_file_send(line, network, channel, reply)
        if line['closed'] and @filehandles[line['handle'].to_i]
            puts 'file sent'
            @filehandles[line['handle'].to_i].close
            @filehandles.delete_at(line['handle'].to_i)
            return
        end
        if reply.command['name']
            @filehandles[line['handle'].to_i] = @filedescriptors[reply.command['name']]
        end
        
        file = @filehandles[line['handle'].to_i]

        length = line['end'].to_i - line['start'].to_i
        send_command('1', 'file send;handle='+line['handle'], length)
        file.seek(line['start'].to_i)
        data = file.read(length)
        @connection.send(data)
        return
    end
    
    #list the connected presences
    def reply_presence_list(line, network, channel, reply)
        if line['network'] and line['presence']
            unless network = @serverlist[line['network'], line['presence']]
                network = @serverlist.add(line['network'], line['presence'])
            end
            #network = createnetworkifnot(line['network'], line['presence'])
            network.set_username(line['name'] ) if line['name']
            if line['connected']
                network.connect
                network.loggedin = true
                @window.redraw_channellist
                switchchannel(network)
            end
        end
        if line['reply_status'] == '+'
                send_command('channels', "channel list")
        end
    end
    
    def reply_network_list(line, network, channel, reply)
        if line['network'] and !@networks.include?(line['network'])
            @networks.push(line['network'])
        elsif line['reply_status'] == '+'
            send_command('presences', 'presence list')
        end
    end
    
    #list the connected channels
    def reply_channel_list(line, network, channel, reply)
        if line['network'] and line['presence'] and line['channel']
            if !@serverlist[line['network'], line['presence']]
                puts 'network does not exist '+line['network']+', '+line['presence']
            else
                unless channel = @serverlist[line['network'], line['presence']][line['channel']]
                    channel = @serverlist[line['network'], line['presence']].add(line['channel'])
                end
                
                if line['joined'] and channel
                    if line['topic']
                        channel.topic = line['topic']
                    end
                    channel.connect
                    switchchannel(channel)
                end
            end
        
        elsif line['reply_status'] == '+'
            syncchannels unless @syncchannels
        end
        
    end
    
    #~ def reply_channel_init(line, network, channel, reply)
        #~ if line['network'] and line['presence'] and line['channel']
            #~ send_command('join', 'channel join;network='+line['network']+';presence='+line['presence']+';channel='+line['channel'])
        #~ end
    #~ end
    
    #list of users on the channel
    def reply_channel_names(line, network, channel, reply)
        if line['network'] and line['presence'] and line['channel'] and line['name']
            network.users.create(line['name'])
            chuser = channel.users.add(network.users[line['name']])
            #channel.adduser(line['name'], true)
            if line['status']
                chuser.add_mode(line['status'])
                puts 'set '+chuser.name+'\'s status to '+line['status']
            end
        elsif line['reply_status'] == '+'
            @serverlist[reply.command['network'], reply.command['presence']][reply.command['channel']].drawusers
            @window.updateusercount
            @serverlist[reply.command['network'], reply.command['presence']][reply.command['channel']].usersync = true
        end
    end

    #handle past events here
    def reply_event_get(line, network, channel, reply)
        reply.network ||= network if network
        reply.channel ||= channel if channel
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
            #~ if line['topic'] and line['topic_set_by']
                #~ pattern = "Topic set to %6"+line['topic']+ "%6 by %6"+line['topic_set_by']+'%6'
            #~ elsif line['topic']
                #~ pattern ="Topic for %6"+line['channel']+ "%6 is %6"+line['topic']+'%6'
            #~ elsif line['topic_set_by']
                #~ pattern = "Topic for %6"+line['channel']+ "%6 set by %6"+line['topic_set_by']+'%6 at %6'+line['topic_timestamp']+'%6'
            #~ end
            #~ line['msg'] = pattern

            if line['topic'] or line['topic_set_by']
                channel.send_event(line, TOPIC, BUFFER_START)
                channel.topic = line['topic'] if line['topic']
                @window.updatetopic
            end
            
            #~ if pattern
                #~ channel.send_event(line, NOTICE, BUFFER_START)
            #~ end
            
        elsif line['event'] == 'channel_presence_removed'
            return if line['deinit']
            
            if line['name'] == network.username
                channel.send_event(line, USERPART, BUFFER_START)
            else
                channel.send_event(line, PART, BUFFER_START)
            end
        
        elsif line['event'] == 'channel_part'
            channel.send_event(line, USERPART, BUFFER_START)
            #channel.disconnect
            
        elsif line['event'] == 'channel_join'
            #channel.reconnect
            channel.send_event(line, USERJOIN, BUFFER_START)
            
        elsif line['event'] == 'channel_presence_added'
            return if line['init']
            
            if line['name'] == network.username
                channel.send_event(line, USERJOIN, BUFFER_START)
            else
                channel.send_event(line, JOIN, BUFFER_START)
            end
        elsif line['reply_status'] == '+'
            #event.command
            reply.channel.eventsync = true if reply.channel
            #Thread.new{syncchannels}
        end
    end
    
	#output the result of a whois
	def reply_presence_status(reply)
		network = @serverlist[reply.command['network'], reply.command['presence']]
		
		reply.lines.each do |line|
		
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
				logintime = duration(Time.at(line['time'].to_i) - Time.at(line['login_time'].to_i))
				msg = 'Idle: '+idletime+' -- Logged on: '+Time.at(line['login_time'].to_i).strftime('%c')+' ('+logintime+')'
			elsif line['channels']
				msg = line['channels']
			elsif line['extra']
				msg = line['extra']
			elsif line['reply_status'] == '+'
				msg = 'End of /whois'
				line['name'] = reply.command['name']
			else
				next
			end
			
			pattern = $config['whois'].deep_clone
			pattern['%m'] = msg if msg
			pattern['%n'] = line['name'] if line['name']
			line['msg'] = pattern
			network.send_event(line, NOTICE)
			time = line['time']
		end
	end

end