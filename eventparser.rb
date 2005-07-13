module EventParser
    #handle normal output from irssi2
	def event_parse(event)
        
		#trap for events that refer to a channel that does not exist
		if event['network'] and event['presence']
			if !@serverlist[event['network'], event['presence']]
			else
				network = @serverlist[event['network'], event['presence']]
			end
			
			if event['channel'] and network
				if !network[event['channel']]
				else
					channel = @serverlist[event['network'], event['presence']][event['channel']]
				end
			end
        end
        
        if self.respond_to?('event_'+event['type'])
            res = callback('event_'+event['type'], event, network, channel)
            #if res.class == Array and res.length > 0
            self.send('event_'+event['type'], *res)
            #else
            #    self.send('event_'+event['type'], event, network, channel)
            #end
        end
    end
    
    #connecting to a server
    def event_gateway_connecting(event, network, channel)
        #return unless network
        if !@serverlist[event['network'], event['presence']]
            network = @serverlist.add(event['network'], event['presence'])
            network.connect
            @window.redraw_channellist
            switchchannel(network)
        elsif @serverlist[event['network'], event['presence']].connected.nil?
            network = @serverlist[event['network'], event['presence']]
            network.connect
            @window.redraw_channellist
            switchchannel(network)
        elsif !@serverlist[event['network'], event['presence']].connected
            puts 'server exists but is not connected, reconnecting'
            network = @serverlist[event['network'], event['presence']]
            network.reconnect
        else
            puts 'request to create already existing network, ignoring'
            return
        end
        msg = "Connecting to "+event['ip']
        msg += ":"+event['port'] if event['port']
        event['msg'] = msg
        network.send_event(event, NOTICE)
    end
    
    #disconnected from a network
    def event_gateway_disconnected(event, network, channel)
        if network
            line = {'msg' => 'Disconnected from '+network.name}
            network.send_user_event(line, NOTICE)
            network.chats.each {|chat| chat.disconnect}
            network.disconnect
        end
    end
    
    def event_gateway_logged_in(event, network, channel)
        return unless network
        
        network.loggedin = true
        Thread.new do
            network.bufferedcommands.each do |command|
                puts 'sending command '+command+' to network '+network.name
                command_parse(command, nil, network, network.presence)
            end
        end
    end
    
    def event_network_init(event, network, channel)
        event['msg'] = 'Added '+event['protocol']+' server '+event['network']
        @window.currentbuffer.send_event(event, NOTICE)
    end
    
    #joined a channel
    def event_channel_init(event, network, channel )
        return unless network
        if !@serverlist[event['network'], event['presence']]
            puts 'Error, non existant channel init event caught for non existant network, ignoring'
            return
        elsif @serverlist[event['network'], event['presence']][event['channel']]
            puts 'request to create already existing channel, ignoring'
            return
        else
            channel = @serverlist[event['network'], event['presence']].add(event['channel'])
            channel.usersync = channel.eventsync = true
        end
    end
    
    def event_channel_join(event, network, channel)
        #return unless network
        #puts 'trying to join '+event['channel']
        if !@serverlist[event['network'], event['presence']]
            puts 'Error, non existant channel init event caught for non existant network, ignoring'
            return
        elsif channel = @serverlist[event['network'], event['presence']][event['channel']] and channel.connected.nil?
           # puts 'connecting '+event['channel']
            channel.connect
            #@window.redraw_channellist
            switchchannel(channel)
        elsif channel = @serverlist[event['network'], event['presence']][event['channel']] and !channel.connected
            puts 'channel exists, but is not connected, reconnecting'
            channel.reconnect
        end
    end
    
    #notice from the server
    def event_notice(event, network, channel)
        return unless network
        network.send_event(event, NOTICE)
    end
    
    #you left the channel
    def event_channel_presence_removed(event, network, channel)
        return unless channel
        if ! event['deinit']
            if event['name'] == network.username
                channel.send_event(event, USERPART)
            else
                channel.send_event(event, PART)
            end
            channel.deluser(event['name'])
            @window.updateusercount
        else
            channel.deluser(event['name'], true)
        end
    end
    
    #you left the channel
    def event_channel_part(event, network, channel)
        return unless channel
        channel.send_event(event, USERPART)
        channel.disconnect
        channel.clearusers
        @serverlist.renumber
    end
    
    #~ #user joined a channel
    #~ def event_channel_join(event, network, channel)
        #~ return unless channel
        #~ channel.reconnect
        #~ channel.send_event(event, USERJOIN)
    #~ end
    
    #another user joined the channel
    def event_channel_presence_added(event, network, channel)
        return unless channel
        if !event['init']
            channel.adduser(event['name'], false)
            if event['name'] == network.username
                channel.send_event(event, USERJOIN)
            else
                channel.send_event(event, JOIN)
                @window.updateusercount
            end
        elsif
            channel.adduser(event['name'], true)
        end
    end
    
    #a user has changed
    def event_presence_changed(event, network, channel)
        return unless network
        if event['new_name']
        
            if event['name'] == network.username
                network.set_username(event['new_name'])
                @window.get_username
                @window.show_username
            end
            pattern = $config['notice'].deep_clone
            
            user = network.users[event['name']]
            
            if user
                user.rename(event['new_name'])
                network.channels.each do |channel|
                    if channel.users[user.name]
                        #remove the user and readd him before the redraw
                        channel.deluser(user.name)
                        channel.adduser(user.name)
                        channel.drawusers
                    end
                end
            end
            
            if event['new_name'] == network.username
                pattern = 'You are now known as '+event['new_name']
            elsif event['name'] != event['new_name']
                pattern= event['name']+' is now known as '+event['new_name']
            else
                pattern = nil
            end
            
            event['msg'] = pattern
            
            if pattern
                network.channels.each{ |c|
                    if c.users[event['new_name']]
                        c.drawusers
                        c.send_event(event, NOTICE)
                    end
                }
            end
            
            if event['name'] and chat = network.has_chat?(event['name'])
                chat.rename(event['new_name'])
            end
            
        end
	
        if event['address']
            if user = network.users[event['name']]
                user.hostname = event['address']
            end
        end
    end
    
    #a user has caught irssi2's attention
    def event_presence_init(event, network, channel)
        return unless network
        network.users.create(event['name'], event['address'])
    end
    
    #a user has left irssi2's attention
    def event_presence_deinit(event, network, channel)
        return unless network
        network.users.remove(event['name'])
    end
    
    #a message is recieved
    def event_msg(event, network, channel)
        return unless network
        if event['nick']
            user = network.users[event['nick']]
            if user
                user.lastspoke = event['time']
                if !user.hostname
                    user.hostname = event['address']
                end
            end
        end
    
        if !event['channel'] and event['no-autoreply']
            if event['nick']
                network.send_event(event, MESSAGE)
            else
                network.send_event(event, NOTICE)
            end
            return
        elsif !event['channel'] and event['nick']
            if !network.has_chat?(event['nick'])
                chat = network.addchat(event['nick'])
                chat.connect
            else
                chat = network.has_chat?(event['nick'])
                chat.connect unless chat.connected
            end
            chat.send_event(event, MESSAGE)
            return
        elsif !event['channel']
            return
        end
    
        if event['address'] and network.users[event['name']] and network.users[event['name']].hostname == 'hostname'
            network.users[event['name']].hostname = event['address']
        end
        
        return unless channel
        if event['own']
            channel.send_event(event, USERMESSAGE)
        else
            channel.send_event(event, MESSAGE)
        end
    end
    
    #connected to a server
	def event_gateway_connected(event, network, channel)
        return unless network
        msg = "Connected to "+event['ip']
        msg += ":"+event['port'] if event['port']
        event['msg'] = msg
        network.send_event(event, NOTICE)
    end
    
    #failed to connect to a server
    def event_gateway_connect_failed(event, network, channel)
        return unless network
        if event['ip']
            err = "Connection to "+event['ip']+':'+event['port']+" failed : "+event['error']
            event['err'] = err
        else
            event['err'] = event['error']
        end
        
        network.send_event(event, ERROR)
    end
    
    #the gateway has changed
    def event_gwconn_changed(event, network, channel)
        gateway_changed(event, network, channel)
    end
    
    #the gateway has changed
    def gateway_changed(event, network, channel)
        return unless network
        if event['irc_mode']
            msg = event['presence']+" sets mode +"+event['irc_mode']+" "+event['presence']
            event['msg'] = msg
            network.send_event(event, NOTICE)
        end
    end
    
    #server's message of the day
    def event_gateway_motd(event, network, channel)
        return unless network
        event['msg'] = event['data']
        network.send_event(event, NOTICE)
    end
    
    #a channel has changed
    def event_channel_changed(event, network, channel)
        return unless channel
        if event['initial_presences_added']
            #puts 'initial presences added'
            @window.updateusercount
            channel.drawusers
        end
        #~ elsif event['topic'] and event['topic_set_by']
            #~ #pattern = "Topic set to %6"+event['topic']+ "%6 by %6"+event['topic_set_by']+'%6'
            #~ pattern = "%6"+event['topic_set_by']+'%6 has changed the topic to: %6'+event['topic']+'%6'
        #~ elsif event['topic']
            #~ pattern ="Topic for %6"+event['channel']+ "%6 is %6"+event['topic']+'%6'
        #~ elsif event['topic_set_by']
            #~ pattern = "Topic for %6"+event['channel']+ "%6 set by %6"+event['topic_set_by']+'%6 at %6'+event['topic_timestamp']+'%6'
        #~ end
        #~ event['msg'] = pattern
        
        if event['topic'] or event['topic_set_by']
            channel.topic = event['topic'] if event['topic']
            channel.send_event(event, TOPIC)
            @window.updatetopic
        end
        
        #~ if pattern
            #~ channel.send_event(event, NOTICE)
        #~ end
    end
    
    def event_irc_event(event, network, channel)
    end
    
    def event_silc_event(event, network, channel)
    end
    
    def event_presence_status_changed(event, network, channel)
        return unless network
        if user = network.users[event['name']]
            user.lastspoke = event['idle_started']
        end
    end
    
end