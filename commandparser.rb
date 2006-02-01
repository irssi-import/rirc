class Main   
    def command_parse(message, target)

        #TODO - fix this?
        #~ if network and !network.loggedin
        #~ throw_message('buffering command '+message)
        #~ network.bufferedcommands.push(message)
        #~ return
        #~ end

#         message = check_aliases(message)

        if /^(\/\w+)(?: (.+)|)/.match(message)
            command = $1
            arguments = $2
        end

        if command and command[0].chr == '/'
            if result = @config['aliases'].detect{|k,v| '/'+k.downcase == message[0..k.length].downcase}
                Alias.new(result[1], arguments, target).commands.each{|x|sleep 0.1;command_parse(x, target)}
                return
            else
                cmd = command[1, command.length].downcase
            end
        end

        begin
            if cmd and self.respond_to?('cmd_'+cmd)
                res = callback('cmd_'+cmd, arguments, target)
                return if res === true
                self.send('cmd_'+cmd, *res)
            else
                res = callback('cmd_message', message, target)
                self.send('cmd_message', *res)
            end
            #rescue any exceptions...
        rescue =>exception
            puts 'Error parsing commmand : '+$!
            puts exception.backtrace
        end
    end

    def check_aliases(command)
        #TODO - allow command chaining, implement $@ and maybe something for all unmatched parameters
        #feed the result back into command_parse so aliases can point to aliases

        #~ cmd, args = command.split(' ', 2)
        #~ cmd.sub!('/', '')
        #~ if $config['aliases'].has_key?(cmd)
        #~ puts cmd+' => '+$config['aliases'][cmd]
        #~ end

        #~ command
        @config['aliases'].each do |original, cmdalias|
            if command[0, original.length+1].downcase == '/'+original.downcase
                #puts 'found alias '+original
                if cmdalias.include?('$')
                    args = command[original.length+1..-1]
                    return command unless args[0].chr == ' ' or args.length == 0
#                     puts args[0].chr, args.length
                    args = args.strip.split(' ')
                    #puts args

                    cmd = cmdalias.dup

                    re = /(\$(\d+))/
                    md = re.match(cmd)

                    while md
                        var = args[$2.to_i]
                        var ||= ''
                        cmd.gsub!($1, var)
                        md = re.match(cmd)
                    end
                    return cmd
                else
                    return command unless command[original.length+1..-1].length == 0 or command[original.length+1..-1][0].chr == ' '
                    return command.sub(command[0, original.length+1], cmdalias)
                end
            end
        end
        command
    end

    #/exec support, -o makes it output to the channel
    help :cmd_exec, "executes a command, the -o switch makes it output to the channel"
    def cmd_exec(message, target)
        return unless message

        output = false

        if message[0,2] == '-o'
            output = true
            message = message[3..-1]
        end

        res = `#{message}`
        res.chomp
        if $? == 0 and res
            res.split("\n").each do |msg|
                if output
                    if target.class == ChannelBuffer or target.class == ChatBuffer
                        reply = send_command('message'+rand(100).to_s, "msg;#{target.identifier_string};#{escape(msg)}")
                    end
                end
                lineref = target.send_user_event({'msg' => msg}, EVENT_USERMESSAGE)
                reply.lineref = lineref if reply
            end
        end

    end

    help :cmd_message, "Sends a message to the channel"
    def cmd_message(message, target)
        #its not a command, treat as a message
        if target.respond_to? :username
            #puts message
            messages = message.split("\n")
            messages.each do |message|
                if target.class == ChannelBuffer
                    rep = send_command('message'+rand(100).to_s, 'msg;network='+target.network.name+';channel='+target.name+';msg='+escape(message)+";mypresence="+target.presence)
                elsif target.class == ChatBuffer
                    rep = send_command('message'+rand(100).to_s, 'msg;network='+target.network.name+';presence='+target.name+';msg='+escape(message)+";mypresence="+target.presence)
                end
                line = {}
                line[PRESENCE] = target.presence
                line[MSG] = message
                lineref = target.send_user_event(line, EVENT_USERMESSAGE)
                rep.lineref = lineref if rep
            end
        else
            #line = {}
            throw_error('Invalid server command')
        end
    end

    #/join command
    help :cmd_join, "Join a channel. usage: /join <channel>"
    def cmd_join(arguments, target)
        return unless target
#         puts arguments, target, target.joined?
        if !arguments and target.respond_to? :join and !target.joined?
#             puts target.name
            arguments = target.name
        end
        send_command('join', "channel join;#{target.network.identifier_string};channel=#{arguments}") if arguments
    end

    #/server command
    help :cmd_server, "Define a server. usage: /server <name>:<protocol>:<address>[:<port>]"
    def cmd_server(arguments, target)
        if arguments  =~ /^([a-zA-Z0-9_\-]+):([a-zA-Z]+):([a-zA-Z0-9_.\-]+)(?:$|:(\d+))/
            network_add($1, $2, $3, $4)
        else
            error_throw('Usage: /server <name>:<protocol>:<address>[:<port>]')
        end
    end

    #/connect command
    help :cmd_connect, "Connect to a network. Usage: /connect <Network> <Presence>"
    def cmd_connect(arguments, target)
        unless arguments
            throw_error('Specify a network to connect to.')
            return
        end
        network, presence = arguments.split(' ', 2)

        unless presence
            #presence = $config['presence']
            throw_error('Specify a presence to use.')
        end

        if presence_add(network, presence)
            network_connect(network, presence)
        end
    end

    #/disconnect command
    help :cmd_disconnect, "Disconnect from a network. Usage: /disconnect [Network]"
    def cmd_disconnect(arguments, target)
        if target.respond_to? :network and target.network.connected?
            send_command('disconnect', "presence disconnect;#{target.network.identifier_string}")
        elsif !target.network.connected?
            throw_error('Cannot disconnect, network already disconnected')
        else
            throw_error('/disconnect does not function in this tab without a network argument')
        end
    end
#         unless target.respond
#             if !arguments
#                 throw_error('/disconnect does not function in this tab without a network argument')
#                 return
#             end
#         end

#         if network and !arguments
#             servername = network.name
#             presence = network.presence
#         else
#             servername, presence = arguments.split(' ', 2)
#         end

#         if presence
#         elsif target.network.name == networkname
#             presence = target.presence
#         else
#             results = @serverlist.get_network_by_name(networkname)

#             if results
#                 results.delete_if {|server| !server.connected}
#             end

#             if results and results.length == 1
#                 presence = results[0].presence
#             elsif results and results.length > 1
#                 throw_error('Multiple networks named '+servername+' please specify a presence')
#             else
#                 throw_error('No network named '+servernames)
#             end
#         end

#         if presence and servername
#             send_command('disconnect'+servername, "presence disconnect;network="+servername+";mypresence="+presence)
#             server = @serverlist[servername, presence]
#             server.disconnect
#             #
#             #server.close if server
#         end
#     end

    #/part command
    help :cmd_part, "Leave a channel. Usage: /part [channel]"
    def cmd_part(arguments, target)
        unless target.respond_to? :topic
            throw_error('/part does not function in this tab.')
            return
        end
        if arguments
            channame = arguments.split(' ')
        end

        if channame
            send_command('part', "channel part;#{target.network.identifier_string};channel="+channame[0])
        elsif target
            send_command('part', "channel part;#{target.identifier_string}")
        else
            error_throw('Part requires a channel argument or it must be called from a channel tab.')
        end
    end

    help :cmd_close, "Close current buffer, will close all children of current buffer"
    def cmd_close(arguments, target)
        if target.respond_to? :connect
            send_command('disconnect', "presence disconnect;#{target.identifier_string}")
            @buffers.values.select{|x| x.network == target}.each do |buffer|
                buffer.close
            end
        elsif target.respond_to? :topic
            send_command('part', "channel part;#{target.identifier_string}")
            target.close
        else
            target.close
        end
    end

    #/quit command
    help :cmd_quit, "Quit Ratchet"
    def cmd_quit(arguments, target)
        send_command('quit', 'quit')
        Gtk.main_quit
        quit
    end

    #/shutdown command
    help :cmd_shutdown, "Kill Icecapd and quit Ratchet"
    def cmd_shutdown(arguments, target)
        send_command('shutdown', 'shutdown')
        Gtk.main_quit
        quit
    end

    help :cmd_topic, "Get or print the topic. Usage: /topic [newtopic]"
    def cmd_topic(arguments, target)
        unless channel
            error_throw('/topic only functions in a channel tab')
            return
        end

        if arguments
            $main.send_command('topicchange', 'channel change;network='+network.name+';mypresence='+network.presence+';channel='+channel.name+';topic='+escape(arguments))
        else
#             puts channel.topic
            event = {'init' => true, 'line'=>1, CHANNEL=>channel.name, TOPIC=>channel.topic}
            target.send_user_event(event, EVENT_TOPIC)
            #event = {'msg' => channel.topic}
            #@window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end


    #/ruby command
    help :cmd_ruby, "Blindly execute ruby code"
    def cmd_ruby(arguments, target)
        unless arguments
            throw_error('Give me some code to execute')
            return
        end
        throw_message('possibly evil ruby code inputted, blindly executing')
        eval(arguments)
    end

    #/raw command
    help :cmd_raw, "Send raw icecap messages to icecapd"
    def cmd_raw(arguments, target)
        unless arguments
            throw_error('Specify a string to send to the server')
            return
        end
        throw_message('Sent raw command "'+arguments+'" to irssi2 directly')
        send_command('raw', arguments)
    end

    #/nick command
    help :cmd_nick, "Change your nickname. Usage: /nick <nickname>"
    def cmd_nick(arguments, target)
        unless target and arguments
            unless target.respond_to? :username
                throw_error('/nick command does not function in this tab.')
                return
            end
            if !arguments
                throw_error('Usage: /nick <nickname>')
                return
            end
        end
        name, bleh = arguments.split(' ', 2)
        send_command('nick'+name, "presence change;#{target.network.identifier_string};name=#{name}")
    end

    #/whois command
    help :cmd_whois, "Get the whois info on somebody"
    def cmd_whois(arguments, target)
        unless target.respond_to? :network
            throw_error('/whois command does not function in this tab.')
            return
        end
        if arguments
            name, bleh = arguments.split(' ', 2)
        else
            name = target.username
        end
        send_command('whois'+name, "presence status;#{target.network.identifier_string};presence=#{name}")
    end

    #/msg command
    help :cmd_msg, "Message another user. Usage: /msg <username> <message>"
    def cmd_msg(arguments, target)
        unless target.respond_to? :presence
            throw_error('/msg does not function in this tab')
            return
        end

        if arguments
            nick,msgs = arguments.split(' ', 2)
        end

        if nick and msgs
            messages = msgs.split("\n")
            messages.each do |message|
                send_command('msg'+rand(100).to_s, 'msg;network='+target.network.name+';presence='+nick+';msg='+message+";mypresence="+target.presence)
                if buffer = find_buffer(target.network.name, target.presence, nil, nick)
                    buffer.send_user_event({'msg'=>message}, EVENT_USERMESSAGE)
                end
            end  
        else
            throw_error('/msg requires a username and a message')

        end
    end

    help :cmd_query, "Open a new chat buffer, and optionaly message the user. Usage: /query <username> [message]"
    def cmd_query(arguments, target)
        if arguments
            nick,msgs = arguments.split(' ', 2)
            chat = add_buffer(target.network.name, target.presence, nil, nick) if nick
#             puts chat
            cmd_msg(arguments, chat) if msgs and chat
            #             chat.send_user_event({'msg'=>msgs}, EVENT_USERMESSAGE)
        end
    end


    help :cmd_me, "Does an emote"
    def cmd_me(arguments, target)
        unless target.respond_to? :users and target.network != target
            throw_error('/me does not function in this tab')
            return
        end
        reply = send_command('message'+rand(100).to_s, "msg;#{target.identifier_string};msg=#{escape(arguments)};type=action")
        lineref = target.send_user_event({'msg'=>arguments, 'type'=>'action'}, EVENT_USERMESSAGE)
        reply.lineref = lineref
    end

    help :cmd_networks, "List all defined networks"
    def cmd_networks(arguments, target)
        lines = ['Defined networks:']
        @networks.list.each {|network| lines.push(network.name+' - '+network.protocol)}

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end
    end

    help :cmd_protocols, "List all supported protocols"
    def cmd_protocols(arguments, target)
        lines = ['Defined protocols']
        @protocols.list.each {|protocol| lines.push("#{protocol.name} - #{protocol.charsets_in.join(', ')}, #{protocol.charset_out}") }

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end
    end

    help :cmd_gateways, "List all defined gateways"
    def cmd_gateways(arguments, target)
        lines = ['Defined gateways:']

        #~ @serverlist.servers.each do |server|
        #~ network, presence = server.getnetworkpresencepair
        #~ if server.connected
        #~ lines.push(network+' - '+presence+' - Connected')
        #~ else
        #~ lines.push(network+' - '+presence)
        #~ end
        #~ end

        @networks.list.each do |network|
            network.gateways.list.each do|gateway|
                x = gateway.host
                x += ':'+gateway.port if gateway.port
                lines.push(x)
            end
        end

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end

        #@presences.each {|presence| lines.push(presence[0]+' - '+presence[1])}
    end

    help :cmd_presences, "List all defined presences"
    def cmd_presences(arguments, target)
        lines = ['Defined Presences:']

        #~ @serverlist.servers.each do |server|
        #~ network, presence = server.getnetworkpresencepair
        #~ if server.connected
        #~ lines.push(network+' - '+presence+' - Connected')
        #~ else
        #~ lines.push(network+' - '+presence)
        #~ end
        #~ end

        @networks.list.each do |network|
            network.presences.list.each do|presence|
                lines.push(network.name+' - '+presence.name)
            end
        end

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end

    end


    help :cmd_channels, "List all defined channels"
    def cmd_channels(arguments, target)
        lines = ['Defined Channels:']

        @buffers.values.select{|x| x.class == ChannelBuffer}.sort{|x, y| x.name<=>y.name}.each do |channel|
            if channel.joined?
                lines.push(channel.network.name+' - '+channel.presence+' - '+channel.name+' - Connected')
            else
                lines.push(channel.network.name+' - '+channel.presence+' - '+channel.name)
            end
        end

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end
    end

    if $args['debug']
        def cmd_reload(arguments, target)
            if !arguments.include? '.'
                arguments += '.rb'
            end
            begin
                eval("load '#{arguments}'")
            rescue LoadError
                puts "failed to load #{arguments}"
            else
                puts "reload of #{arguments} sucessful"
            end
        end
    end

    help :cmd_load, "Specify a plugin to load. Usage: /load <name>"
    def cmd_load(arguments, target)
        unless arguments
            throw_error('Specify a plugin to load.')
            return
        end
        plugin_load(arguments)
    end

    help :cmd_unload, "Specify a plugin to unload. Usage: /unload <name>"
    def cmd_unload(arguments, *args)
        unless arguments
            throw_error('Specify a plugin to unload.')
            return
        end
        if plugin = Plugin[arguments]
            Plugin.unregister(plugin)
        else
            throw_error('No plugin found called '+arguments)
        end
    end

    help :cmd_pluginlist, "List all loaded plugins"
    def cmd_pluginlist(arguments, target)
        lines = ['Loaded Plugins:']
        plugins = Plugin.list
        plugins.each do |key, values|
            #             v.each do |key, values|
            temp = values['name']
            #                 values.each do |value|
            #                     #puts k.name, key, value
            #                     temp += ' '+value[1].to_s+'#'+value[0]
            #                 end
            lines.push(temp)
            #             end
        end

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end
    end

    help :cmd_alias, "Define an alias. Usage: /alias <aliasname> <aliascommand>"
    def cmd_alias(arguments, target)
        splitter = ' '
        if arguments.include?(' /')
            splitter = ' /'
        end
        original, cmdalias = arguments.split(splitter, 2).map{|e| e.strip}

        if splitter == ' /'
            cmdalias = '/'+cmdalias
        end

        puts 'aliased '+original+' to '+cmdalias

        #puts original.class, cmdalias.class

        @config['aliases'] ||= {}
        @config['aliases'][original] = cmdalias
    end

    help :cmd_unalias, "Remove an alias. Usage: /unalias <aliasname>"
    def cmd_unalias(arguments, target)

        cmd, other = arguments.split(' ', 2)

        cmd.strip!

        @config['aliases'].delete(cmd)

        puts 'unaliased '+cmd
    end

    help :cmd_aliases, "List all defined aliases"
    def cmd_aliases(arguments, target)
        lines = ['Aliases:']

        @config['aliases'].each do |original, cmdalias|
#             puts original.class, cmdalias.class
            lines.push(original+' => '+cmdalias)
        end

        lines.push(' ')

        lines.each do |line|
            event = {'msg' => line}
            target.send_user_event(event, EVENT_NOTICE)
        end
    end

    help :cmd_help, "Get help on commands. Usage: /help [command]"
    def cmd_help(arguments, target)
        #puts 'help', self
        #puts self.class.methods - self.class.superclass.methods
        command_methods = command_list
        if arguments
#             command_methods = (self.methods).select{|method| method =~ /^cmd_/}
#             command_methods = command_methods.select{|method| method[4..-1] == arguments}
            command_methods = command_methods.detect{|method| method[1..-1] == arguments}
#             command_methods ||= @config['aliases'].detect{|k,v| k == arguments}[0]
        end
        
        return unless command_methods
        
        unless arguments
            event = {'msg' => "Interactive help system"}
            target.send_user_event(event, EVENT_NOTICE)
            event = {'msg' => "<> denotes a required argument, [] denotes an optional one"}
            target.send_user_event(event, EVENT_NOTICE)
            event = {'msg' => ""}
            target.send_user_event(event, EVENT_NOTICE)
        end

        command_methods.sort.each do |method|
#             puts method, self.methods.include?('cmd_'+method[1..-1]), @config['aliases'][method[1..-1]]
            if self.methods.include? 'cmd_'+method[1..-1]
                if self.help('cmd_'+method[1..-1])
                    event = {'msg' => method+' : '+self.help('cmd_'+method[1..-1]).to_s}
                    target.send_user_event(event, EVENT_NOTICE)
                else
                    event = {'msg' => method+" : Undocumented command"}
                    target.send_user_event(event, EVENT_NOTICE)
                end
            elsif al = @config['aliases'][method[1..-1]]
                event = {'msg' => "#{method} : alias for #{al}"}
                target.send_user_event(event, EVENT_NOTICE)
            end
        end
    end    

    def command_list
        a = (self.methods).select{|method| method =~ /^cmd_/}.map{|x| '/'+(x[4..-1])}
        a += @config['aliases'].keys.map{|x| '/'+x}
        #TODO - aliases too
        a.sort
    end
end
