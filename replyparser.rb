module ReplyParser
    #handle replies from irssi2 (responses to commands sent from a client)
    def reply_parse(reply)
    
        #~ puts 'dispatch'
        #target = dispatch(reply.command[NETWORK], reply.command[MYPRESENCE],  reply.command[CHANNEL], reply.command[PRESENCE])
        #~ puts "target is #{target.class}"
        #~ return

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
            puts 'config get'
            @config.parse_config(reply)
            return
        end
            
        reply.lines.each do |line|
            
            if reply.name == 'raw'
                @console.send_user_event({'msg' =>line['original']}, EVENT_NOTICE)
                next
            end
            
            #~ if line[NETWORK] and line[MYPRESENCE]
                #~ if !@serverlist[line[NETWORK], line[MYPRESENCE]]
                #~ else
                    #~ network = @serverlist[line[NETWORK], line[MYPRESENCE]]
                #~ end
                
                #~ if line[CHANNEL] and @serverlist[line[NETWORK], line[MYPRESENCE]]
                    #~ if !@serverlist[line[NETWORK], line[MYPRESENCE]][line[CHANNEL]]
                    #~ else
                        #~ channel = @serverlist[line[NETWORK], line[MYPRESENCE]][line[CHANNEL]]
                    #~ end
                #~ end
            #~ #elsif reply.command[NETWORK] and reply.command[MYPRESENCE]
            #~ end
            
            target = find_buffer(line[NETWORK], line[MYPRESENCE],  line[CHANNEL], line[PRESENCE])
            #puts line.inspect unless target
            #puts "#{[line[NETWORK], line[MYPRESENCE],  line[CHANNEL], line[PRESENCE]].inspect} => #{target.class}"
            
            begin
                cmd = 'reply_'+reply.command['command'].gsub(' ', '_')
                if self.respond_to?(cmd)
                    res = callback(cmd, line, target, reply)
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
    
    def reply_msg(line, target, reply)
        if line['msg_reply'] and reply.lineref
#             puts reply.name, reply.command[NETWORK], reply.command[CHANNEL], reply.command[MYPRESENCE]
            if reply.command[NETWORK] and reply.command[CHANNEL] and reply.command[MYPRESENCE]
                channel = @serverlist[reply.command[NETWORK], reply.command[MYPRESENCE]][reply.command[CHANNEL]]
#                 puts reply.command[:type]
                #hack to handle actions
                #TODO: try to do this a better way
                if reply.command[:type] == 'action'
                    iter = channel.view.get_line(reply.lineref)
#                     puts iter[2], channel.server.username
                    start, rest = iter[2].split(channel.server.username)
                    line['msg_reply'] = start+channel.server.username+' '+line['msg_reply']
                end
                channel.view.update_line(reply.lineref, line['msg_reply'])
            end
            #@window.view.
        end
    end

    #sending a file
    def reply_file_send(line, target, reply)
        if line['handle']
            if line['closed'] and @filehandles[line['handle'].to_i]
#                 puts 'file sent'
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
    
    def reply_quit(line, target, reply)
        puts 'got quit confirmation'
        do_quit
#         if @quitting
#             @quit = true
#             do_quit
#         end
    end
    
    #list the connected presences
    def reply_presence_list(line, target, reply)
        if line[NETWORK] and line[MYPRESENCE]
            network = add_buffer(line[NETWORK], line[MYPRESENCE])
            #~ unless network = @serverlist[line[NETWORK], line[MYPRESENCE]]
                #~ network = @serverlist.add(line[NETWORK], line[MYPRESENCE])
            if nw = @networks[line[NETWORK]]
                presence = nw.add_presence(line[MYPRESENCE])
                presence.autoconnect = true if line[AUTOCONNECT] and presence
            end
            #~ end
            network.username = line[PRESENCE] if line[PRESENCE]
#             puts
            if line[CONNECTED]
                network.connect
                puts 'connected network'
                #~ network.loggedin = true
                #~ @window.redraw_channellist
                #~ #switchchannel(network)
                #~ @tabmodel.set_active(network)
            end
        end
        if line[REPLY_STATUS] == '+'
            send_command('channels', "channel list")
        end
    end
    
    def reply_network_list(line, target, reply)
        if line[NETWORK] and !@networks[line[NETWORK]]
            @networks.add(line[NETWORK], line[PROTOCOL])
        elsif line[REPLY_STATUS] == '+'
            send_command('gateways', 'gateway list')
        end
    end
    
    def reply_gateway_list(line, target, reply)
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
    
    def reply_protocol_list(line, target, reply)
        if line[PROTOCOL] and !@protocols[line[PROTOCOL]]
            @protocols.add(line[PROTOCOL], line[:in_charsets], line[:out_charset])
        elsif line[REPLY_STATUS] == '+'
            send_command('networks', 'network list')
        end
    end

    def reply_window_add(line, target, reply)
       puts "#{reply.network}, #{reply.presence}, #{reply.channel}"
       puts line['original']
       if target = find_buffer(reply.network, reply.presence, reply.channel)
           target.window_id = line['window'] if line['window']
           target.last_seen = line['last_seen_event_id'] if line['last_seen_event_id']
        end
    end
    
    #list the connected channels
    def reply_channel_list(line, target, reply)
#         puts 'channel list', line.inspect
        if line[NETWORK] and line[MYPRESENCE] and line[CHANNEL]
#             puts 'adding channel'
            if channel = add_buffer(line[NETWORK], line[MYPRESENCE], line[CHANNEL])
#                 reply = send_command("window#{rand(100)}", "window add;filter=&(network=#{line[NETWORK]})(mypresence=#{line[MYPRESENCE]})(channel=#{line[CHANNEL]})")
#                 reply.network = line[NETWORK]
#                 reply.presence = line[MYPRESENCE]
#                 reply.channel = line[CHANNEL]
#                 puts "new channel #{channel}"
                if line[JOINED] and channel
                    if line[TOPIC]
                        channel.topic = line[TOPIC]
                    end
                    channel.join
                end
            else
                puts 'uh-oh'
            end
            #~ if !@serverlist[line[NETWORK], line[MYPRESENCE]]
                #~ puts 'network does not exist '+line[NETWORK]+', '+line[MYPRESENCE]
            #~ else
                #~ unless channel = @serverlist[line[NETWORK], line[MYPRESENCE]][line[CHANNEL]]
                    #~ channel = @serverlist[line[NETWORK], line[MYPRESENCE]].add(line[CHANNEL])
                #~ end
                
                #~ if line[JOINED] and channel
                    #~ if line[TOPIC]
                        #~ channel.topic = line[TOPIC]
                    #~ end
                    #~ channel.connect
                    #~ #switchchannel(channel)
                    #~ @tabmodel.set_active(channel)
                #~ end
            #~ end
        
        elsif line[REPLY_STATUS] == '+'
            #check for connected networks
            i = 0
            @buffers.values.select{|x| x.class == NetworkBuffer}.each do |network|
                i+=1 if network.connected?
            end
            
            #if no networks are connected, raise the network window
            if i == 0
                @windows[0].open_networks
            end
            syncchannels
        end
        
    end
    
    #list of users on the channel
    def reply_channel_names(line, target, reply)
        #puts reply.class
        #network = assign_window.buffers.find_network(reply.command[NETWORK], reply.command[MYPRESENCE])
        #if network
        #    channel = network[reply.command[CHANNEL]]
        #end
        #puts network, channel
        #if line[NETWORK] and line[MYPRESENCE] and line[CHANNEL] and line[PRESENCE]
        #puts "userlist #{target.class}"
        target = find_buffer(reply.command[NETWORK], reply.command[MYPRESENCE], reply.command[CHANNEL], line[PRESENCE])
        if reply.command[NETWORK] and reply.command[MYPRESENCE] and reply.command[CHANNEL] and line[PRESENCE] and target and !target.users.include?(line[PRESENCE])
            target.network.users.create(line[PRESENCE])
            chuser = target.users.add(target.network.users[line[PRESENCE]], false)
            if line[MODE] and chuser
                chuser.mode= line[MODE]
            end
        elsif line[REPLY_STATUS] == '+'
            #@serverlist[reply.command[NETWORK], reply.command[MYPRESENCE]][reply.command[CHANNEL]].drawusers
            #@window.updateusercount
            #@serverlist[reply.command[NETWORK], reply.command[MYPRESENCE]][reply.command[CHANNEL]].usersync = true
            target = find_buffer(reply.command[NETWORK], reply.command[MYPRESENCE], reply.command[CHANNEL])
            target.usersync = true
            target.users.sort
            target.users.fill_view
        end
    end

    #handle past events here
    def reply_event_get(line, target, reply)
        #reply.network ||= target.network if target
        reply.channel ||= target if target and target.respond_to? :join
        #puts "#{[line[NETWORK], line[MYPRESENCE],  line[CHANNEL], line[PRESENCE]].inspect} => #{target.class}"
        if line[EVENT] == 'msg'
            puts line.inspect unless target
            return unless target
            if line[ADDRESS] and target.network.users[line[PRESENCE]] and target.network.users[line[PRESENCE]].hostname == 'hostname'
                target.network.users[line[PRESENCE]].hostname = line[ADDRESS]
            end
            
            #TODO - fix this
            #~ if line[PRESENCE] and !line[NO_AUTOREPLY] and !line[CHANNEL]
                #~ unless target = network.has_chat?(line[PRESENCE])
                    #~ target = network.addchat(line[PRESENCE])
                    #~ puts 'chat for '+line[PRESENCE]
                    #~ puts line['original']
                #~ end
                #~ target.connect unless target.connected
            #~ end
                
            if line[OWN]
		#I don't know why I did this, but I'm fixing something else ATM so 'll come back to it
                #line[PRESENCE] = line[PRESENCE]
                target.send_event(line, EVENT_USERMESSAGE, BUFFER_START)
            else
                target.send_event(line, EVENT_MESSAGE, BUFFER_START)
            end
            
        elsif line[EVENT] == 'notice'
            return unless target
            target.send_event(event, EVENT_NOTICE, BUFFER_START)
            
        elsif line[EVENT] == 'channel_changed'
            if line[TOPIC] and line['init']
                #send the topic stuff as 2 lines
                #channel.topic = line[TOPIC]
                line['line'] = 2
                target.send_event(line, EVENT_TOPIC, BUFFER_START)
                line['line'] = 1
                target.send_event(line, EVENT_TOPIC, BUFFER_START)
                #@window.updatetopic
            elsif line[TOPIC]
                #channel.topic = line[TOPIC]
                target.send_event(line, EVENT_TOPIC, BUFFER_START)
                #@window.updatetopic
            end
            
        elsif line[EVENT] == 'presence_changed'
            #this doesn't seem to be reached, ever
            if line[NAME]
                if line[NAME] == network.username
                    type = EVENT_USERNICKCHANGE
                else
                    type = EVENT_NICKCHANGE
                end
                
                if type
                    network.channels.each do |c|
                        if c.users[line[NAME]]
                            #this isn't really a great thing to be doing ATM
                            #c.drawusers
                            #c.send_event(line, type, BUFFER_START)
                        end
                    end
                end
            end
            
        elsif line[EVENT] == 'channel_presence_removed'
            return if line[DEINIT]
            line[:type] = 'part'
            if line[PRESENCE] == target.username
                target.send_event(line, EVENT_USERPART, BUFFER_START)
            else
                target.send_event(line, EVENT_PART, BUFFER_START)
            end
        
        elsif line[EVENT] == 'channel_part'
            line[:type] = 'part'
            target.send_event(line, EVENT_USERPART, BUFFER_START)
            
        elsif line[EVENT] == 'channel_join'
            target.send_event(line, EVENT_USERJOIN, BUFFER_START)
            
        elsif line[EVENT] == 'channel_presence_added'
            return if line[INIT]
            
            if line[PRESENCE] == target.username
                target.send_event(line, EVENT_USERJOIN, BUFFER_START)
            else
                target.send_event(line, EVENT_JOIN, BUFFER_START)
            end
            
        elsif line[REPLY_STATUS] == '+'
            reply.channel.eventsync = true if reply.channel
        end
    end
    
    #output the result of a whois
    def reply_presence_status(reply)
        target ||= find_buffer(reply.command[NETWORK], reply.command[MYPRESENCE])
        
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
            
            pattern = @config['whois'].dup
            pattern['%m'] = msg if msg
            if line[PRESENCE]
                pattern['%n'] = line[PRESENCE]
            else
                pattern['%n'] = reply.command[PRESENCE]
            end
            line[MSG] = pattern
            target.send_event(line, EVENT_NOTICE)
            time = line[TIME]
        end
    end

end
