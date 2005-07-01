module EventParser
    #handle events from irssi2 (responses to commands sent from a client)
	def handle_event(event)

		if event.command['command'] == 'presence status'
			whois(event)
			return
		elsif event.command['command'] == 'config get'
			$config.parse_config(event)
			return
		end
		
		event.lines.each do |line|
			
            channel = nil
            network = nil
            
			if event.name == 'raw'
				output = {}
				output['msg'] =  line['original']
				@serverlist.send_event(output, NOTICE)
				next
			end
			
			if line['status'] == '-'
				line['err'] = 'Error: '+line['error']+' encountered when sending command '+event.origcommand
				@serverlist.send_event(line, ERROR)
				return
			end
            
            if line['network'] and line['presence']
                if !@serverlist[line['network'], line['presence']]
                    #puts 'Error, non existant network event caught, ignoring'
                else
                    network = @serverlist[line['network'], line['presence']]
                end
                
                if line['channel']
                    if !@serverlist[line['network'], line['presence']][line['channel']]
                        #puts 'Error, non existant channel event caught, ignoring '+line['network']+' '+line['presence']+' '+line['channel']+' '+event.origcommand
                        #return
                    else
                        channel = @serverlist[line['network'], line['presence']][line['channel']]
                    end
                end
            end
            
            cmd = 'ev_'+event.command['command'].gsub(' ', '_')
            if self.respond_to?(cmd)
                self.send(cmd, line, network, channel, event)
            else
                puts 'no method to handle '+cmd+' event.'
            end
        end
    end

    #sending a file
    def ev_file_send(line, network, channel, event)
        if line['closed'] and @filehandles[line['handle'].to_i]
            puts 'file sent'
            @filehandles[line['handle'].to_i].close
            @filehandles.delete_at(line['handle'].to_i)
            return
        end
        if event.command['name']
            @filehandles[line['handle'].to_i] = @filedescriptors[event.command['name']]
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
    def ev_presence_list(line, network, channel, event)
        if line['network'] and line['presence']
            network = createnetworkifnot(line['network'], line['presence'])
            network.set_username(line['name'] ) if line['name']
            send_command('channels', "channel list")
        end
    end
    
    #list the connected channels
    def ev_channel_list(line, network, channel, event)
        
        if line['network'] and line['presence'] and line['name']
            if @serverlist[line['network'], line['presence']] and !@serverlist[line['network'], line['presence']][line['name']]
                channel = @serverlist[line['network'], line['presence']].add(line['name'])
                if line['topic']
                    channel.topic = line['topic']
                end
                switchchannel(channel)
                puts 'getting channel info'
                send_command('listchan-'+line['network']+line['name'], "channel names;network="+line['network']+";channel="+line['name']+";presence="+line['presence'])
                send_command('events-'+line['network']+line['name'], "event get;end=*;limit=500;filter=(channel="+line['name']+")")
            else
                puts 'channel call for existing network, ignoring '+line['network']+' '+line['presence']+' '+line['name']
                return
            end
        end
        
    end
    
    #list of users on the channel
    def ev_channel_names(line, network, channel, event)
        if line['network'] and line['presence'] and line['channel'] and line['name']
            network.users.create(line['name'])
            channel.adduser(line['name'], true)
            @window.updateusercount
        elsif line['status'] == '+'
            puts 'end of user list'
            @serverlist[event.command['network'], event.command['presence']][event.command['channel']].drawusers
            @window.updateusercount
        end
    end
                    
    #handle past events here
    def ev_event_get(line, network, channel, event)
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
            channel.disconnect
            
        elsif line['event'] == 'channel_join'
            channel.reconnect
            channel.send_event(line, USERJOIN, BUFFER_START)
            
        elsif line['event'] == 'channel_presence_added'
            return if line['init']
            
            if line['name'] == network.username
                channel.send_event(line, USERJOIN, BUFFER_START)
            else
                channel.send_event(line, JOIN, BUFFER_START)
            end
        end
    end

end