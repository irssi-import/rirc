module LineParser
    #handle normal output from irssi2
	def parse_line(line)
    
		#trap for events that refer to a channel that does not exist
		if line['network'] and line['presence']
			if !@serverlist[line['network'], line['presence']]
				#puts 'Error, non existant network event caught, ignoring'
				#return
			else
				network = @serverlist[line['network'], line['presence']]
			end
			
			if line['channel']
				if !@serverlist[line['network'], line['presence']][line['channel']]
					#puts 'Error, non existant channel event caught, ignoring '+line['network']+' '+line['presence']+' '+line['channel']
					#return
				else
					channel = @serverlist[line['network'], line['presence']][line['channel']]
				end
			end
        end
        
        if self.respond_to?(line['type'])
            self.send(line['type'], line, network, channel)
        else
            puts 'no method to handle '+line['type']+' event.'
        end
    end
    
    #connecting to a server
    def gateway_connecting(line, network, channel)
        #return unless network
        if !@serverlist[line['network'], line['presence']]
            network = @serverlist.add(line['network'], line['presence'])
            switchchannel(network)
        elsif !@serverlist[line['network'], line['presence']].connected
            puts 'server exists but is not connected, reconnecting'
            network = @serverlist[line['network'], line['presence']]
            network.reconnect
        else
            puts 'request to create already existing network, ignoring'
            return
        end
        msg = "Connecting to "+line['ip']
        msg += ":"+line['port'] if line['port']
        line['msg'] = msg
        network.send_event(line, NOTICE)
    end

    #joined a channel
    def channel_init(line, network, channel )
        return unless network
        if !@serverlist[line['network'], line['presence']]
            puts 'Error, non existant channel init event caught for non existant network, ignoring'
            return
        elsif @serverlist[line['network'], line['presence']][line['channel']] and ! @serverlist[line['network'], line['presence']][line['channel']].connected
            puts 'channel exists, but is not connected, reconnecting'
            @serverlist[line['network'], line['presence']][line['channel']].reconnect
            
        elsif @serverlist[line['network'], line['presence']][line['channel']]
            puts 'request to create already existing channel, ignoring'
            return
        else
            switchchannel(@serverlist[line['network'], line['presence']].add(line['channel']))
        end
    end
    
    #notice from the server
    def notice(line, network, channel)
        return unless network
        network.send_event(line, NOTICE)
    end
    
    #another user left the channel
    def channel_presence_removed(line, network, channel)
        return unless channel
        if ! line['deinit']
            if line['name'] == network.username
                channel.send_event(line, USERPART)
            else
                channel.send_event(line, PART)
            end
            channel.deluser(line['name'])
            @window.updateusercount
        else
            channel.deluser(line['name'], true)
        end
    end
    
    #user left the channel
    def channel_part(line, network, channel)
        return unless channel
        channel.send_event(line, USERPART)
        channel.disconnect
    end
    
    #user joined a channel
    def channel_join(line, network, channel)
        return unless channel
        channel.reconnect
        channel.send_event(line, USERJOIN)
    end
    
    #another user joined the channel
    def channel_presence_added(line, network, channel)
        return unless channel
        if !line['init']
            channel.adduser(line['name'])
            if line['name'] == network.username
                channel.send_event(line, USERJOIN)
            else
                channel.send_event(line, JOIN)
                @window.updateusercount
            end
        elsif
            channel.adduser(line['name'], false)
        end
    end
    
    #a user has changed
    def presence_changed(line, network, channel)
        return unless network
        if line['new_name']
        
            if line['name'] == network.username
                network.set_username(line['new_name'])
                @window.get_username
                @window.show_username
            end
            pattern = $config['notice'].deep_clone
            
            user = network.users[line['name']]
            
            if user
                user.rename(line['new_name'])
            end
            
            if line['new_name'] == network.username
                pattern = 'You are now known as '+line['new_name']
            elsif line['name'] != line['new_name']
                pattern= line['name']+' is now known as '+line['new_name']
            else
                pattern = nil
            end
            
            line['msg'] = pattern
            
            if pattern
                network.channels.each{ |c|
                    if c.users[line['new_name']]
                        c.drawusers
                        c.send_event(line, NOTICE)
                    end
                }
            end
        end
	
        if line['address']
            if user = network.users[line['name']]
                user.hostname = line['address']
            end
        end
    end
    
    #a user has caught irssi2's attention
    def presence_init(line, network, channel)
        return unless network
        network.users.create(line['name'], line['address'])
    end
    
    #a user has left irssi2's attention
    def presence_deinit(line, network, channel)
        return unless network
        network.users.remove(line['name'])
    end
    
    #a message is recieved
    def msg(line, network, channel)
        return unless network
        if line['nick']
            user = network.users[line['nick']]
            if user
                user.lastspoke = line['time']
                if !user.hostname
                    user.hostname = line['address']
                end
            end
        end
    
        if !line['channel'] and line['no-autoreply']
            if line['nick']
                network.send_event(line, MESSAGE)
            else
                network.send_event(line, NOTICE)
            end
            return
        elsif !line['channel'] and line['nick']
            if !network.chat_exists?(line['nick'])
                chat = network.addchat(line['nick'])
            else
                chat = network.chat_exists?(line['nick'])
            end
            chat.send_event(line, MESSAGE)
            return
        elsif !line['channel']
            return
        end
    
        if line['address'] and network.users[line['name']] and network.users[line['name']].hostname == 'hostname'
            network.users[line['name']].hostname = line['address']
        end
        
        if line['own']
            channel.send_event(line, USERMESSAGE)
        else
            channel.send_event(line, MESSAGE)
        end
    end
    
    #connected to a server
	def gateway_connected(line, network, channel)
        return unless network
        msg = "Connected to "+line['ip']
        msg += ":"+line['port'] if line['port']
        line['msg'] = msg
        network.send_event(line, NOTICE)
    end
    
    #failed to connect to a server
    def gateway_connect_failed(line, network, channel)
        return unless network
        err = "Connection to "+line['ip']+':'+line['port']+" failed : "+line['error']
        line['err'] = err
        network.send_event(line, ERROR)
    end
    
    #the gateway has changed
    def gwconn_changed(line, network, channel)
        gateway_changed(line, network, channel)
    end
    
    #the gateway has changed
    def gateway_changed(line, network, channel)
        return unless network
        msg = line['presence']+" sets mode +"+line['irc_mode']+" "+line['presence']
        line['msg'] = msg
        network.send_event(line, NOTICE)
    end
    
    #server's message of the day
    def gateway_motd(line, network, channel)
        return unless network
        line['msg'] = line['data']
        network.send_event(line, NOTICE)
    end
    
    #a channel has changed
    def channel_changed(line, network, channel)
        return unless channel
        if line['initial_presences_added']
            puts 'initial presences added'
            @window.updateusercount
        end
        #~ elsif line['topic'] and line['topic_set_by']
            #~ #pattern = "Topic set to %6"+line['topic']+ "%6 by %6"+line['topic_set_by']+'%6'
            #~ pattern = "%6"+line['topic_set_by']+'%6 has changed the topic to: %6'+line['topic']+'%6'
        #~ elsif line['topic']
            #~ pattern ="Topic for %6"+line['channel']+ "%6 is %6"+line['topic']+'%6'
        #~ elsif line['topic_set_by']
            #~ pattern = "Topic for %6"+line['channel']+ "%6 set by %6"+line['topic_set_by']+'%6 at %6'+line['topic_timestamp']+'%6'
        #~ end
        #~ line['msg'] = pattern
        
        if line['topic'] or line['topic_set_by']
            channel.topic = line['topic'] if line['topic']
            channel.send_event(line, TOPIC, BUFFER_START)
            @window.updatetopic
        end
        
        #~ if pattern
            #~ channel.send_event(line, NOTICE)
        #~ end
    end
    
    def irc_event(line, network, channel)
    end
    
    def silc_event(line, network, channel)
    end
    
end