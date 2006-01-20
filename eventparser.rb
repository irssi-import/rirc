module EventParser
    #handle normal output from irssi2
    def event_parse(event)
        #trap for events that refer to a channel that does not exist
        #~ if event[NETWORK] and event[MYPRESENCE]
        #~ if !@serverlist[event[NETWORK], event[MYPRESENCE]]
        #~ else
        #~ network = @serverlist[event[NETWORK], event[MYPRESENCE]]
        #~ end

        #~ if event[CHANNEL] and network
        #~ if !network[event[CHANNEL]]
        #~ else
        #~ channel = @serverlist[event[NETWORK], event[MYPRESENCE]][event[CHANNEL]]
        #~ end
        #~ end
        #~ end

        target = find_buffer(event[NETWORK], event[MYPRESENCE], event[CHANNEL], event[PRESENCE])
        #puts "#{[event[NETWORK], event[MYPRESENCE], event[CHANNEL], event[PRESENCE]].inspect} => #{target}"

        begin
            if self.respond_to?('event_'+event['event_type'])
                res = callback('event_'+event['event_type'], event, target)
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
    def event_gateway_connecting(event, target)
        if !target
            network = add_buffer(event[NETWORK], event[MYPRESENCE])
        elsif !target.connected?
            puts 'network '+event[NETWORK]+' exists but is not connected, reconnecting'
            network = @window.networks(event[NETWORK], event[MYPRESENCE])
            network.reconnect
        else
            puts 'request to create already existing network, ignoring'
            return
        end
        msg = "Connecting to "+event['ip']
        msg += ":"+event[PORT] if event[PORT]
        event['msg'] = msg
        @window.networks.send_event(network, event, EVENT_NOTICE)
    end

    #disconnected from a network
    def event_gateway_disconnected(event, target)
        if target
            line = {'msg' => 'Disconnected from '+target.name}
            target.send_user_event(line, EVENT_NOTICE)
            #network.chats.each {|chat| chat.disconnect}
            target.disconnect
        end
    end

    def event_gateway_logged_in(event, target)
        return #unless target
        target.loggedin = true
        Thread.new do
            target.bufferedcommands.each do |command|
                puts 'sending command '+command+' to network '+target.name
                command_parse(command, target)
            end
        end
    end

    def event_gateway_init(event, target)
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

    def event_gateway_deinit(event, target)
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

    def event_network_init(event, target)
        @networks.add(event[NETWORK], event[PROTOCOL])
        throw_message('Added '+event[PROTOCOL]+' server '+event[NETWORK])
    end

    def event_network_set(event, target)
        #TODO - update network settings here
    end

    def event_local_presence_init(event, target)
        @networks[event[NETWORK]].presences.add(event[MYPRESENCE])
    end

    def event_local_presence_deinit(event, target)
        ps = @networks[event[NETWORK]].presences[event[MYPRESENCE]]
        if ps
            @networks[event[NETWORK]].presences.remove(ps)
        end
    end

    #joined a channel
    def event_channel_init(event, target)
        return unless target
        if !find_buffer(event[NETWORK], event[MYPRESENCE])
            puts 'Error, non existant channel init event caught for non existant network, ignoring'
            return
        elsif find_buffer(event[NETWORK], event[MYPRESENCE], event[CHANNEL])
            puts 'request to create already existing channel, ignoring'
            return
        else
            puts 'channel added'
            channel = add_buffer(event[NETWORK], event[MYPRESENCE], event[CHANNEL])
            channel.usersync = channel.eventsync = true
            #send_command('events-'+network.name+channel.name, 'event get;end=*;limit=200;filter=&(channel='+channel.name+')(network='+network.name+')(presence='+network.presence+')(!(event=client_command_reply))')
        end
    end

    def event_channel_join(event, target)
        puts 'channel join'
        puts "TARGET: #{target}"
        #return unless target.respond_to? :join
        #~ if !assign_window.find_network(event[NETWORK], event[MYPRESENCE])
        #~ puts 'Error, non existant channel init event caught for non existant network, ignoring'
        #~ return
        #~ elsif channel = assign_window.buffers.add_channel(event[NETWORK], event[MYPRESENCE], event[CHANNEL]) and !channel.joined?
        if !target and channel = add_buffer(event[NETWORK], event[MYPRESENCE], event[CHANNEL])
            channel.join
            send_command('events-'+channel.network.name+channel.name, 'event get;end=*;limit=200;filter=&(channel='+channel.name+')(network='+channel.network.name+')(mypresence='+channel.network.presence+')(!(|(event=client_command_reply)(init=*)(deinit=*)(raw=*)))(time>1)')
        elsif target.respond_to? :join and !target.joined?
            puts 'channel exists, but is not connected, reconnecting'
            target.join
        else
            #puts channel.name, channel.connected
        end
    end

    #notice from the server
    def event_notice(event, target)
        return unless target
        target.send_event(event, EVENT_NOTICE)
    end

    #you left the channel
    def event_channel_presence_removed(event, target)
        return unless target
        if ! event[DEINIT]
            if event[PRESENCE] == target.username
                target.send_event(event, EVENT_USERPART)
            else
                target.send_event(event, EVENT_PART)
            end
            target.users.remove(event[PRESENCE])#, false)
            #@window.updateusercount
            #channel.drawusers
        else
            #target.users.remove(event[PRESENCE])
        end
    end

    #you left the channel
    def event_channel_part(event, target)
        return unless target
        target.send_event(event, EVENT_USERPART)
        target.part
        #@serverlist.renumber
    end

    #another user joined the channel
    def event_channel_presence_added(event, target)
        return unless target
        if user = target.network.users[event[PRESENCE]]
            if !event[INIT]
                chuser = target.users.add(user)
                if event[PRESENCE] == target.username
                    target.send_event(event, EVENT_USERJOIN)
                else
                    target.send_event(event, EVENT_JOIN)
                end
            else
                chuser = target.users.add(user)#, false)
            end
            if event[MODE]
                chuser.mode=event[MODE]
                puts 'set '+chuser.name+'\'s status to '+event[MODE]
                #~ if !event[INIT]
                #~ channel.drawusers
                #~ end
                target.users.reorder(chuser)
            end
        else
            puts 'unknown user '+event[PRESENCE]
        end
    end

    #a user has changed
    def event_presence_changed(event, target)
        target ||= find_buffer(event[NETWORK], event[MYPRESENCE])
        return unless target
        if event[NAME]
            #network = find_buffer(event[NETWORK], event[MYPRESENCE])
            if event[PRESENCE] == target.username
                target.network.username = event[NAME]
                #@window.get_username
                #@window.show_username
            end
            pattern = @config['notice'].dup

            user = target.network.users[event[PRESENCE]]

            if user
                puts user.inspect
                user.rename(event[NAME])
                puts user.inspect
                @buffers.values.select{|x| x.network == target.network and  x.network != x and x.users}.each do |channel|
                    if chuser = channel.users[user.name]
                        channel.users.reorder(chuser)
                    end
                end
            end

            if event[NAME] == target.username
                type = EVENT_USERNICKCHANGE
            else
                type = EVENT_NICKCHANGE
            end

            if type
                @buffers.values.select{|x| x.network == target.network and  x.network != x and x.users}.each do |c|
                    if c.users[event[NAME]]
                        c.send_event(event, type)
                    end
                end
            end

            #TODO - handle chat renaming
            #if event[PRESENCE] and chat = network.has_chat?(event[PRESENCE])
            #    chat.rename(event[NAME])
            #end

        end

        if event[ADDRESS]
            if user = target.network.users[event[PRESENCE]]
                user.hostname = event[ADDRESS]
            end
        end
    end

    #a user has caught irssi2's attention
    def event_presence_init(event, target)
        target = find_buffer(event[NETWORK], event[MYPRESENCE])
        return unless target
#         puts "adding network presence #{event[PRESENCE]} to #{target.name}"
        target.network.users.create(event[PRESENCE], event[ADDRESS])
    end

    #a user has left irssi2's attention
    def event_presence_deinit(event, target)
        target = find_buffer(event[NETWORK], event[MYPRESENCE])
        return unless target
        target.network.users.remove(event[PRESENCE])
    end

    #a message is recieved
    def event_msg(event, target)
        if target and event[PRESENCE]
            user = target.network.users[event[PRESENCE]]
            if user
                user.lastspoke = event[TIME]
                if !user.hostname
                    user.hostname = event[ADDRESS]
                end
            end
        end

        if !event[CHANNEL] and event[NO_AUTOREPLY]
            target = find_buffer(event[NETWORK], event[MYPRESENCE])
#             puts "target is #{target}"
            return unless target
            if event[PRESENCE]
                target.send_event(event, EVENT_MESSAGE)
            else
                target.send_event(event, EVENT_NOTICE)
            end
            return
        elsif !event[CHANNEL] and event[PRESENCE] and chat = add_buffer(event[NETWORK], event[MYPRESENCE], nil, event[PRESENCE])
            if event[OWN]
                chat.send_event(event, EVENT_USERMESSAGE)
            else
                chat.send_event(event, EVENT_MESSAGE)
            end
            return
        elsif !event[CHANNEL]
            return
        end

        if event[ADDRESS]  and target and target.network.users[event[PRESENCE]] and target.network.users[event[PRESENCE]].hostname == 'hostname'
            target.network.users[event[PRESENCE]].hostname = event[ADDRESS]
        end

        return unless target and target.respond_to? :join
        if event[OWN]
            target.send_event(event, EVENT_USERMESSAGE)
        else
            unless target.users.include?(event[PRESENCE])
                puts "missing user #{event[PRESENCE]}"
                #send_command('listchan-'+target.network.name+target.name, "channel names;#{target.identifier_string}")
                #puts 'Forcing a userlist sync'
            end
            target.send_event(event, EVENT_MESSAGE)
        end
    end

    #connected to a server
    def event_gateway_connected(event, target)
        return unless target
        target.connect
        msg = "Connected to "+event[IP]
        msg += ":"+event[PORT] if event[PORT]
        event['msg'] = msg
        target.send_event(event, EVENT_NOTICE)
    end

    #failed to connect to a server
    def event_gateway_connect_failed(event, target)
        return unless target
        if event['ip']
            err = "Connection to "+event['ip']+':'+event[PORT]+" failed : "+event[ERROR]
            event['err'] = err
        else
            event['err'] = event[ERROR]
        end

        target.send_event(event, EVENT_ERROR)
    end

    #the gateway has changed
    def event_gwconn_changed(event, target)
        gateway_changed(event, target)
    end

    #the gateway has changed
    def event_gateway_changed(event, target)
        return unless target
        if event[IRC_MODE]
            msg = event[MYPRESENCE]+" sets mode +"+event[IRC_MODE]+" "+event[MYPRESENCE]
            event['msg'] = msg
            target.send_event(event, EVENT_NOTICE)
        end
    end

    #server's message of the day
    def event_gateway_motd(event, target)
        return unless target
        event['msg'] = event['data']
        target.send_event(event, EVENT_NOTICE)
    end

    #a channel has changed
    def event_channel_changed(event, target)
        return unless target
        if event['initial_presences_added']
            #@window.updateusercount
            #target.drawusers
        end

        if event[TOPIC] and event[INIT]
            #send the topic stuff as 2 lines
            target.topic = event[TOPIC]
            event['line'] = 1
            target.send_event(event, EVENT_TOPIC)
            event['line'] = 2
            target.send_event(event, EVENT_TOPIC)
            #@window.updatetopic
        elsif event[TOPIC]
            target.topic = event[TOPIC]
            target.send_event(event, EVENT_TOPIC)
            #@window.updatetopic
        end
    end

    def event_client_config_changed(event, target)
        value = @config.decode_value(event['value'])

        @config[event['key'].sub('rirc_', '')] = value
#         @window.draw_from_config
#         restyle
        @windows.each{|win| win.draw_from_config}
    end

    def event_irc_event(event, target)
    end

    def event_silc_event(event, target)
    end

    def event_channel_presence_mode_changed(event, target)
        if target and target.users[event[PRESENCE]]
            target.users[event[PRESENCE]].mode=event[MODE]
            target.users.reorder(target.users[event[PRESENCE]])
            if event[ADD]
                target.send_event(event, EVENT_MODECHANGE)
            elsif event[REMOVE]
                target.send_event(event, EVENT_MODECHANGE)
            end
            #channel.drawusers
            #@window.updateusercount
        else
            if !target
                puts 'no such channel as '+event[CHANNEL]
            elsif !target.users[event[PRESENCE]]
                puts 'no such user '+event[PRESENCE]+' on '+event[CHANNEL]
            end
        end
    end

    def event_presence_status_changed(event, target)
        return unless target
        if user = target.network.users[event[PRESENCE]]
            user.lastspoke = event['idle_started']
        end
    end

end
