module EventParser
    #handle normal output from irssi2
	def event_parse(event)
		#trap for events that refer to a channel that does not exist
		if event[NETWORK] and event[MYPRESENCE]
			if !@serverlist[event[NETWORK], event[MYPRESENCE]]
			else
				network = @serverlist[event[NETWORK], event[MYPRESENCE]]
			end
			
			if event[CHANNEL] and network
				if !network[event[CHANNEL]]
				else
					channel = @serverlist[event[NETWORK], event[MYPRESENCE]][event[CHANNEL]]
				end
			end
        end
        
        begin
            if self.respond_to?('event_'+event['event_type'])
                res = callback('event_'+event['event_type'], event, network, channel)
                return if res === true
                self.send('event_'+event['event_type'], *res)
            end
        #rescue any exceptions...
        rescue =>exception
            puts 'Error parsing event : '+$!
            puts exception.backtrace
        end
    end
    
    #connecting to a server
    def event_gateway_connecting(event, network, channel)
        #return unless network
        if !@serverlist[event[NETWORK], event[MYPRESENCE]]
            network = @serverlist.add(event[NETWORK], event[MYPRESENCE])
            network.connect
            @window.redraw_channellist
            switchchannel(network)
        elsif @serverlist[event[NETWORK], event[MYPRESENCE]].connected.nil?
            network = @serverlist[event[NETWORK], event[MYPRESENCE]]
            network.connect
            @window.redraw_channellist
            switchchannel(network)
        elsif !@serverlist[event[NETWORK], event[MYPRESENCE]].connected
            puts 'network '+event[NETWORK]+' exists but is not connected, reconnecting'
            network = @serverlist[event[NETWORK], event[MYPRESENCE]]
            network.reconnect
        else
            puts 'request to create already existing network, ignoring'
            return
        end
        msg = "Connecting to "+event['ip']
        msg += ":"+event[PORT] if event[PORT]
        event['msg'] = msg
        network.send_event(event, EVENT_NOTICE)
    end
    
    #disconnected from a network
    def event_gateway_disconnected(event, network, channel)
        if network
            line = {'msg' => 'Disconnected from '+network.name}
            network.send_user_event(line, EVENT_NOTICE)
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
    
    def event_gateway_init(event, network, channel)
        if event[NETWORK] and event[HOST]
            if @networks[event[NETWORK]]
                if event[PORT]
                    @networks[event[NETWORK]].add_gateway(event[HOST], event[PORT])
                else
                    @networks[event[NETWORK]].add_gateway(event[HOST])
                end
            else
                puts 'unknown network '+event[NETWORK]
            end
        end
    end
    
    def event_gateway_deinit(event, network, channel)
        if event[NETWORK] and event[HOST]
            if @networks[event[NETWORK]]
                #@networks[event[NETWORK]].add_gateway(event[HOST])
                remove = nil
                
                @networks[event[NETWORK]].gateways.list.each do |gw|
                    if event[HOST] == gw.host and event[PORT] == gw.port
                        remove = gw
                        break
                    end
                end
                
                @networks[event[NETWORK]].gateways.remove(remove)
            else
                puts 'unknown network '+event[NETWORK]
            end
        end
    end
    
    def event_network_init(event, network, channel)
        @networks.add(event[NETWORK], event[PROTOCOL])
        throw_message('Added '+event[PROTOCOL]+' server '+event[NETWORK])
    end
    
    def event_network_set(event, network, channel)
        #TODO - update network settings here
    end
    
    def event_local_presence_init(event, network, channel)
        @networks[event[NETWORK]].presences.add(event[MYPRESENCE])
    end
    
    def event_local_presence_deinit(event, network, channel)
        ps = @networks[event[NETWORK]].presences[event[MYPRESENCE]]
        if ps
            @networks[event[NETWORK]].presences.remove(ps)
        end
    end
    
    #joined a channel
    def event_channel_init(event, network, channel )
        return unless network
        if !@serverlist[event[NETWORK], event[MYPRESENCE]]
            puts 'Error, non existant channel init event caught for non existant network, ignoring'
            return
        elsif @serverlist[event[NETWORK], event[MYPRESENCE]][event[CHANNEL]]
            puts 'request to create already existing channel, ignoring'
            return
        else
            puts 'channel added'
            channel = @serverlist[event[NETWORK], event[MYPRESENCE]].add(event[CHANNEL])
            channel.usersync = channel.eventsync = true
            #send_command('events-'+network.name+channel.name, 'event get;end=*;limit=200;filter=&(channel='+channel.name+')(network='+network.name+')(presence='+network.presence+')(!(event=client_command_reply))')
        end
    end
    
    def event_channel_join(event, network, channel)
        puts 'channel join'
        #return unless network
        #puts 'trying to join '+event[CHANNEL]
        if !@serverlist[event[NETWORK], event[MYPRESENCE]]
            puts 'Error, non existant channel init event caught for non existant network, ignoring'
            return
        elsif channel = @serverlist[event[NETWORK], event[MYPRESENCE]][event[CHANNEL]] and channel.connected.nil?
           # puts 'connecting '+event[CHANNEL]
            channel.connect
            #@window.redraw_channellist
            switchchannel(channel)
            send_command('events-'+network.name+channel.name, 'event get;end=*;limit=200;filter=&(channel='+channel.name+')(network='+network.name+')(mypresence='+network.presence+')(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)))')
        elsif channel = @serverlist[event[NETWORK], event[MYPRESENCE]][event[CHANNEL]] and !channel.connected
            puts 'channel exists, but is not connected, reconnecting'
            channel.reconnect
        else
            puts channel.name, channel.connected
        end
    end
    
    #notice from the server
    def event_notice(event, network, channel)
        return unless network
        network.send_event(event, EVENT_NOTICE)
    end
    
    #you left the channel
    def event_channel_presence_removed(event, network, channel)
        return unless channel
        if ! event[DEINIT]
            if event[PRESENCE] == network.username
                channel.send_event(event, EVENT_USERPART)
            else
                channel.send_event(event, EVENT_PART)
            end
            channel.users.remove(event[PRESENCE])
            @window.updateusercount
            channel.drawusers
        else
            channel.users.remove(event[PRESENCE])
        end
    end
    
    #you left the channel
    def event_channel_part(event, network, channel)
        return unless channel
        channel.send_event(event, EVENT_USERPART)
        channel.disconnect
        channel.clearusers
        @serverlist.renumber
    end
    
    #another user joined the channel
    def event_channel_presence_added(event, network, channel)
        return unless channel
        if user = network.users[event[PRESENCE]]
            if !event[INIT]
                chuser = channel.users.add(user)
                channel.drawusers
                #channel.adduser(event['name'], false)
                if event[PRESENCE] == network.username
                    channel.send_event(event, EVENT_USERJOIN)
                else
                    channel.send_event(event, EVENT_JOIN)
                    @window.updateusercount
                end
            else
                chuser = channel.users.add(user)
                #channel.adduser(event['name'], true)
            end
            if event[MODE]
                chuser.add_mode(event[MODE])
                puts 'set '+chuser.name+'\'s status to '+event[MODE]
                #~ if !event[INIT]
                    #~ channel.drawusers
                #~ end
            end
        else
            puts 'unknown user '+event[PRESENCE]
        end
    end
    
    #a user has changed
    def event_presence_changed(event, network, channel)
        return unless network
        if event[NAME]
        
            if event[PRESENCE] == network.username
                network.set_username(event[NAME])
                @window.get_username
                @window.show_username
            end
            pattern = $config['notice'].deep_clone
            
            user = network.users[event[PRESENCE]]
            
            if user
                user.rename(event[NAME])
                network.channels.each do |channel|
                    if channel.users[user.name]
                        channel.drawusers
                    end
                end
            end

            if event[NAME] == network.username
                type = EVENT_USERNICKCHANGE
            else
                type = EVENT_NICKCHANGE
            end
            
            if type
                network.channels.each do |c|
                    if c.users[event[NAME]]
                        c.drawusers
                        c.send_event(event, type)
                    end
                end
            end
            
            if event[PRESENCE] and chat = network.has_chat?(event[PRESENCE])
                chat.rename(event[NAME])
            end
            
        end
	
        if event[ADDRESS]
            if user = network.users[event[PRESENCE]]
                user.hostname = event[ADDRESS]
            end
        end
    end
    
    #a user has caught irssi2's attention
    def event_presence_init(event, network, channel)
        return unless network
        network.users.create(event[PRESENCE], event[ADDRESS])
    end
    
    #a user has left irssi2's attention
    def event_presence_deinit(event, network, channel)
        return unless network
        network.users.remove(event[PRESENCE])
    end
    
    #a message is recieved
    def event_msg(event, network, channel)
        return unless network
        if event[PRESENCE]
            user = network.users[event[PRESENCE]]
            if user
                user.lastspoke = event[TIME]
                if !user.hostname
                    user.hostname = event[ADDRESS]
                end
            end
        end
    
        if !event[CHANNEL] and event[NO_AUTOREPLY]
            if event[PRESENCE]
                network.send_event(event, EVENT_MESSAGE)
            else
                network.send_event(event, EVENT_NOTICE)
            end
            return
        elsif !event[CHANNEL] and event[PRESENCE]
            if !network.has_chat?(event[PRESENCE])
                chat = network.addchat(event[PRESENCE])
                chat.connect
            else
                chat = network.has_chat?(event[PRESENCE])
                chat.connect unless chat.connected
            end
            if event[OWN]
                chat.send_event(event, EVENT_USERMESSAGE)
            else
                chat.send_event(event, EVENT_MESSAGE)
            end
            return
        elsif !event[CHANNEL]
            return
        end
    
        if event[ADDRESS] and network.users[event[PRESENCE]] and network.users[event[PRESENCE]].hostname == 'hostname'
            network.users[event[PRESENCE]].hostname = event[ADDRESS]
        end

        return unless channel
        if event[OWN]
            channel.send_event(event, EVENT_USERMESSAGE)
        else
            channel.send_event(event, EVENT_MESSAGE)
        end
    end
    
    #connected to a server
	def event_gateway_connected(event, network, channel)
        return unless network
        msg = "Connected to "+event[IP]
        msg += ":"+event[PORT] if event[PORT]
        event['msg'] = msg
        network.send_event(event, EVENT_NOTICE)
    end
    
    #failed to connect to a server
    def event_gateway_connect_failed(event, network, channel)
        return unless network
        if event['ip']
            err = "Connection to "+event['ip']+':'+event[PORT]+" failed : "+event[ERROR]
            event['err'] = err
        else
            event['err'] = event[ERROR]
        end
        
        network.send_event(event, EVENT_ERROR)
    end
    
    #the gateway has changed
    def event_gwconn_changed(event, network, channel)
        gateway_changed(event, network, channel)
    end
    
    #the gateway has changed
    def event_gateway_changed(event, network, channel)
        return unless network
        if event[IRC_MODE]
            msg = event[MYPRESENCE]+" sets mode +"+event[IRC_MODE]+" "+event[MYPRESENCE]
            event['msg'] = msg
            network.send_event(event, EVENT_NOTICE)
        end
    end
    
    #server's message of the day
    def event_gateway_motd(event, network, channel)
        return unless network
        event['msg'] = event['data']
        network.send_event(event, EVENT_NOTICE)
    end
    
    #a channel has changed
    def event_channel_changed(event, network, channel)
        return unless channel
        if event['initial_presences_added']
            @window.updateusercount
            channel.drawusers
        end
        
        if event[TOPIC] and event[INIT]
            #send the topic stuff as 2 lines
            channel.topic = event[TOPIC]
            event['line'] = 1
            channel.send_event(event, EVENT_TOPIC)
            event['line'] = 2
            channel.send_event(event, EVENT_TOPIC)
            @window.updatetopic
        elsif event[TOPIC]
            channel.topic = event[TOPIC]
            channel.send_event(event, EVENT_TOPIC)
            @window.updatetopic
        end
    end
    
    def event_client_config_changed(event, network, channel)
        value = $config.decode_valie(event['value'])
        
        $config.set_value(event['key'].sub('rirc_', ''), value)
        @window.draw_from_config
    end
    
    def event_irc_event(event, network, channel)
    end
    
    def event_silc_event(event, network, channel)
    end
    
    def event_channel_presence_mode_changed(event, network, channel)
        if channel and channel.users[event[PRESENCE]]
		if event[ADD]
		    channel.users[event[PRESENCE]].add_mode(event[ADD])
		    channel.send_user_event(event, EVENT_MODECHANGE)
		elsif event[REMOVE]
		    channel.users[event[PRESENCE]].remove_mode(event[REMOVE])
		    channel.send_user_event(event, EVENT_MODECHANGE)
		end
		channel.drawusers
		@window.updateusercount
        else
            if !channel
                puts 'no such channel as '+event[CHANNEL]
            elsif !channel.users[event[PRESENCE]]
                    puts 'no such user '+event[PRESENCE]+' on '+event[CHANNEL]
            end
        end
    end
    
    def event_presence_status_changed(event, network, channel)
        return unless network
        if user = network.users[event[PRESENCE]]
            user.lastspoke = event['idle_started']
        end
    end
    
end