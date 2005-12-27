class Main   
    def command_parse(message, network, presence, channel)

        if network and !network.loggedin
            throw_message('buffering command '+message)
            network.bufferedcommands.push(message)
            return
        end
        
        message = check_aliases(message)

        if /^(\/\w+)(?: (.+)|)/.match(message)
            command = $1
            arguments = $2
        end
        
        if command and command[0].chr == '/'
            cmd = command[1, command.length].downcase
        end
        
        begin
            if cmd and self.respond_to?('cmd_'+cmd)
                res = callback('cmd_'+cmd, arguments, channel, network, presence)
                return if res === true
                    self.send('cmd_'+cmd, *res)
            else
                res = callback('cmd_message', message, channel, network, presence)
                self.send('cmd_message', *res)
            end
        #rescue any exceptions...
        rescue =>exception
            puts 'Error parsing commmand : '+$!
            puts exception.backtrace
        end
    end
    
    def check_aliases(command)
        #~ return command unless command[0].chr == '/'
        
        #~ cmd, args = command.split(' ', 2)
        #~ cmd.sub!('/', '')
        #~ if $config['aliases'].has_key?(cmd)
            #~ puts cmd+' => '+$config['aliases'][cmd]
        #~ end
        
        #~ command
        $config['aliases'].each do |original, cmdalias|
            if command[0, original.length+1].downcase == '/'+original.downcase
                #puts 'found alias '+original
                if cmdalias.include?('$')
                    args = command[original.length+1..-1]
                    return command unless args[0].chr == ' ' or args.length == 0
                    puts args[0].chr, args.length
                    args = args.strip.split(' ')
                    #puts args
                    
                    cmd = cmdalias.dup
                    
                    re = /(\$(\d+))/
                    md = re.match(cmd)
                    
                    while md.class == MatchData
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
    def cmd_exec(message, channel, network, presence)
        return unless message
        
        output = false
        
        if message[0,2] == '-o'
            output = true
            message.slice!(0,2).strip
        end

        res = `#{message}`
        res.chomp
        if $? == 0 and res
            res.split("\n").each do |msg|
                if output
                    if channel.class == ChannelBuffer
                        reply = send_command('message'+rand(100).to_s, 'msg;network='+network.name+';channel='+channel.name+';msg='+escape(msg)+";mypresence="+presence)
                    elsif channel.class == ChatBuffer
                        reply = send_command('message'+rand(100).to_s, 'msg;network='+network.name+';presence='+channel.name+';msg='+escape(msg)+";mypresence="+presence)
                    end
                end
                lineref = @window.currentbuffer.send_user_event({'msg' => msg}, EVENT_USERMESSAGE)
                reply.lineref = lineref
            end
        end
            
    end
    
    help :cmd_message, "Sends a message to the channel"
    def cmd_message(message, channel, network, presence)
        #its not a command, treat as a message
        if network
            #puts message
            messages = message.split("\n")
            messages.each do |message|
                
                if channel.class == ChannelBuffer
                    rep = send_command('message'+rand(100).to_s, 'msg;network='+network.name+';channel='+channel.name+';msg='+escape(message)+";mypresence="+presence)
                elsif channel.class == ChatBuffer
                    rep = send_command('message'+rand(100).to_s, 'msg;network='+network.name+';presence='+channel.name+';msg='+escape(message)+";mypresence="+presence)
                end
                line = {}
                line[PRESENCE] = presence
                line[MSG] = message
                lineref = @window.currentbuffer.send_user_event(line, EVENT_USERMESSAGE)
                rep.lineref = lineref if rep
            end
        elsif !network
            #line = {}
            throw_error('Invalid server command')
        end
    end
    
    #/join command
    help :cmd_join, "Join a channel. usage: /join <channel>"
    def cmd_join(arguments, channel, network, presence)
        return unless network and arguments
        send_command('join', 'channel join;network='+network.name+';mypresence='+presence+';channel='+arguments)
    end
    
    #/server command
    help :cmd_server, "Define a server. usage: /server <name>:<protocol>:<address>[:<port>]"
    def cmd_server(arguments, channel, network, presence)
        if arguments  =~ /^([a-zA-Z0-9_\-]+):([a-zA-Z]+):([a-zA-Z0-9_.\-]+)(?:$|:(\d+))/
            network_add($1, $2, $3, $4)
        else
            error_throw('Usage: /server <name>:<protocol>:<address>[:<port>]')
        end
    end
    
    #/connect command
    help :cmd_connect, "Connect to a network. Usage: /connect <Network> <Presence>"
    def cmd_connect(arguments, channel, network, presence)
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
    def cmd_disconnect(arguments, channel, network,  *args)
        unless network
            if !arguments
                throw_error('/disconnect does not function in this tab without a network argument')
                return
            end
        end
        
        if network and !arguments
            servername = network.name
            presence = network.presence
        else
            servername, presence = arguments.split(' ', 2)
        end
        
        if presence
        elsif @window.currentbuffer.server.name == servername
            presence = @window.currentbuffer.server.presence
        else
            results = @serverlist.get_network_by_name(servername)
            
            if results
                results.delete_if {|server| !server.connected}
            end
            
            if results and results.length == 1
                presence = results[0].presence
            elsif results and results.length > 1
                throw_error('Multiple networks named '+servername+' please specify a presence')
            else
               throw_error('No network named '+servernames)
            end
        end
        
        if presence and servername
            send_command('disconnect'+servername, "presence disconnect;network="+servername+";mypresence="+presence)
            server = @serverlist[servername, presence]
            server.disconnect
            #
            #server.close if server
        end
    end
    
    #/part command
    help :cmd_part, "Leave a channel. Usage: /part [channel]"
    def cmd_part(arguments, channel, network, presence)
        unless network
            throw_error('/part does not function in this tab.')
            return
        end
        if arguments
                channame = arguments.split(' ')
        end
        
        if channame
            send_command('part', "channel part;network="+network.name+";mypresence="+presence+";channel="+channame[0])
        elsif channel
            send_command('part', "channel part;network="+network.name+";mypresence="+presence+";channel="+channel.name)
        else
            error_throw('Part requires a channel argument or it must be called from a channel tab.')
        end
    end
    
    #/quit command
    help :cmd_quit, "Quit RIRC"
    def cmd_quit(arguments, channel, network, presence)
        send_command('quit', 'quit')
        Gtk.main_quit
        quit
    end
    
    #/shutdown command
    help :cmd_shutdown, "Kill Icecapd and quit rirc"
    def cmd_shutdown(arguments, channel, network, presence)
        send_command('shutdown', 'shutdown')
        Gtk.main_quit
        quit
    end
    
    help :cmd_topic, "Get or print the topic. Usage: /topic [newtopic]"
    def cmd_topic(arguments, channel, network, presence)
        unless channel
            error_throw('/topic only functions in a channel tab')
            return
        end
        
        if arguments
            $main.send_command('topicchange', 'channel change;network='+network.name+';mypresence='+network.presence+';channel='+channel.name+';topic='+escape(arguments))
        else
            puts channel.topic
            event = {'init' => true, 'line'=>1, CHANNEL=>channel.name, TOPIC=>channel.topic}
            @window.currentbuffer.send_user_event(event, EVENT_TOPIC)
            #event = {'msg' => channel.topic}
            #@window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    #/silckey command
    help :cmd_silckey, "non-functional"
    def cmd_silckey(arguments, channel, network, presence)
        if arguments =~ /^([^\s]+) ([^\s]+)(?: (\w+)|)$/
        pub = $1
        priv = $2
        pass = $3
        #puts pub, priv, pass
        if pub and priv
            key_pub = pub.to_s.sub('~', ENV['HOME'])
            key_priv = priv.to_s.sub('~', ENV['HOME'])
            
            if File.file?(key_pub) and File.file?(key_priv)
                @keys[$config['presence']] = {'silc_pub' => IO.read(key_pub),
                                            'silc_priv' => Base64.encode64(IO.read(key_priv))}
                puts 'added public key '+key_pub
                puts 'added private key '+key_priv
                if pass and pass.length > 0
                    @keys[$config['presence']]['silc_pass'] = pass
                    puts 'using passphrase'
                end
            else
                puts 'file not found'
            end
        end
        end
    end
    
    #/send command
    help :cmd_send, "non-functional"
    def cmd_send(arguments, channel, network, presence)
        if arguments[0] == '~'[0]
            arguments.sub!('~', ENV['HOME'])#expand ~
        end
        name, path = arguments.reverse.split('/', 2)
        name.reverse!
        path = '' if !path
        path.reverse!
        if File.exists?(arguments)
            @filedescriptors[name] = File.open(arguments, 'r') # create a file descriptor with a key the same as the filename sent to server
            send_command('file send '+name, 'file send;resume;name='+name+';size='+File.size(arguments).to_s)
        else
            throw_error('File '+arguments+' does not exist')
        end
    end
    
    #/ruby command
    help :cmd_ruby, "Blindly execute ruby code"
    def cmd_ruby(arguments, channel, network, presence)
        unless arguments
                throw_error('Give me some code to execute')
                return
        end
        throw_message('possibly evil ruby code inputted, blindly executing')
        eval(arguments)
    end
    
    #/raw command
    help :cmd_raw, "Send raw icecap messages to icecapd"
    def cmd_raw(arguments, channel, network, presence)
        unless arguments
            throw_error('Specify a string to send to the server')
            return
        end
        throw_message('Sent raw command "'+arguments+'" to irssi2 directly')
        send_command('raw', arguments)
    end
    
    #/nick command
    help :cmd_nick, "Change your nickname"
    def cmd_nick(arguments, channel, network, presence)
        unless network and arguments
            if !network
                throw_error('/nick command does not function in this tab.')
                return
            end
            if !arguments
                throw_error('Usage: /nick <nickname>')
                return
            end
        end
        name, bleh = arguments.split(' ', 2)
        send_command('nick'+name, 'presence change;network='+network.name+';mypresence='+presence+';name='+name)
    end
    
    #/whois command
    help :cmd_whois, "Get the whois info on somebody"
    def cmd_whois(arguments, channel, network, presence)
        unless network
            throw_error('/whois command does not function in this tab.')
            return
        end
        if arguments
            name, bleh = arguments.split(' ', 2)
        else
            name = network.username
        end
        send_command('whois'+name, 'presence status;network='+network.name+';mypresence='+presence+';presence='+name)
    end
    
    #/msg command
    help :cmd_msg, "Message another user. Usage: /msg <username> <message>"
    def cmd_msg(arguments, channel, network, presence)
        unless network
            throw_error('/msg does not function in this tab')
            return
        end
        
        if arguments
                nick,msgs = arguments.split(' ', 2)
        end
        
        if nick and msgs
            messages = msgs.split("\n")
            messages.each { |message|
                send_command('msg'+rand(100).to_s, 'msg;network='+network.name+';presence='+nick+';msg='+message+";mypresence="+presence)
            }
            if $config['tabonmsg']
                chat = network.addchat(nick)
                chat.connect
                #@winddow.switch
            end
        else
            throw_error('/msg requires a username and a message')
            
        end
    end
    
    help :cmd_query, "like /msg but doesn't open a new tab..?"
    def cmd_query(*args)
        cmd_msg(*args)
        if args[0]
                nick,msgs = args[0].split(' ', 2)
        end
        
        puts nick
        
        if nick
            #unless $config['tabonmsg']
                chat = args[2].addchat(nick)
                chat.connect
                #@winddow.switch
            #end
        end
    end
    
    
    #~ def cmd_last(arguments, channel, network, presence)
        #~ id = channel.get_last_line_id(presence)
        #~ channel.replace_line(id, 'replacement'+rand(100).to_s)
    #~ end
    
    #~ def cmd_del(arguments, channel, network, presence)
        #~ id = channel.get_last_line_id(presence)
        #~ channel.delete_line(id)
    #~ end
    
    help :cmd_me, "Does an emote"
    def cmd_me(message, channel, network, presence)
       reply = send_command('message'+rand(100).to_s, 'msg;network='+network.name+';channel='+channel.name+';msg='+escape(message)+";mypresence="+presence+';type=action')
       lineref = @window.currentbuffer.send_user_event({'msg'=>message, 'type'=>'action'}, EVENT_USERMESSAGE)
       reply.lineref = lineref
    end
    
    help :cmd_networks, "List all defined networks"
    def cmd_networks(*args)
        lines = ['Defined networks:']
        @networks.list.each {|network| lines.push(network.name+' - '+network.protocol)}
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    help :cmd_protocols, "List all supported protocols"
    def cmd_protocols(*args)
        lines = ['Defined protocols']
        @protocols.list.each {|protocol| lines.push(protocol.name+' - '+protocol.charset) }
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    help :cmd_gateways, "List all defined gateways"
    def cmd_gateways(*args)
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
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
        
        #@presences.each {|presence| lines.push(presence[0]+' - '+presence[1])}
    end
    
    help :cmd_presences, "List all defined presences"
    def cmd_presences(*args)
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
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
        
        #@presences.each {|presence| lines.push(presence[0]+' - '+presence[1])}
    end
    
    
    #~ def cmd_dump(*args)
    
        #~ File.open('dump', 'w+') do |f|
            #~ Marshal.dump(@networks, f)
            #~ Marshal.dump(@protocols, f)
        #~ end
    #~ end
    
    help :cmd_channels, "List all defined channels"
    def cmd_channels(*args)
        lines = ['Defined Channels:']
        
        @serverlist.servers.each do |server|
            server.channels.each do |channel|
                if channel.connected
                    lines.push(server.name+' - '+server.presence+' - '+channel.name+' - Connected')
                else
                    lines.push(server.name+' - '+server.presence+' - '+channel.name)
                end
            end
        end
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    help :cmd_load, "Specify a plugin to load. Usage: /load <name>"
    def cmd_load(arguments, channel, network, presence)
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
        if plugin = Plugin.lookup(arguments)
            Plugin.unregister(plugin)
        else
         throw_error('No plugin found called '+arguments)
        end
    end
    
    help :cmd_pluginlist, "List all loaded plugins"
    def cmd_pluginlist(*args)
        lines = ['Loaded Plugins:']
        plugins = Plugin.list
        plugins.each do |k, v|
            v.each do |key, values|
                temp = k.name+' '+key+':'
                values.each do |value|
                    #puts k.name, key, value
                    temp += ' '+value[1].to_s+'#'+value[0]
                end
                lines.push(temp)
            end
        end
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    help :cmd_alias, "Define an alias. Usage: /alias <aliasname> <aliascommand>"
    def cmd_alias(arguments, channel, network, presence)
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
        
        $config['aliases'][original] = cmdalias
    end
    
    help :cmd_unalias, "Remove an alias. Usage: /unalias <aliasname>"
    def cmd_unalias(arguments, channel, network, presence)
    
        cmd, other = arguments.split(' ', 2)
        
        cmd.strip!
        
        $config['aliases'].delete(cmd)
        
        puts 'unaliased '+cmd
    end
    
    help :cmd_aliases, "List all defined aliases"
    def cmd_aliases(*args)
        lines = ['Aliases:']
        
        $config['aliases'].each do |original, cmdalias|
            puts original.class, cmdalias.class
            lines.push(original+' => '+cmdalias)
        end
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    def cmd_spam(arguments, *args)
        count = 500
        if arguments =~ /[\d]+/
            count = arguments.to_i
        end
        
        count.times do |i|
            event = {'msg' => 'This is testing spam'}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
    end
    
    help :cmd_help, "Get help on commands. Usage: /help [command]"
    def cmd_help(arguments, channel, network, presence)
        #puts 'help', self
        #puts self.class.methods - self.class.superclass.methods
        command_methods = (self.methods).select{|method| method =~ /^cmd_/}
        if arguments
            command_methods = command_methods.select{|method| method[4..-1] == arguments}
        end
        return if command_methods.empty?
        unless arguments
            event = {'msg' => "Interactive help system"}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
            event = {'msg' => ""}
            @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
        end
        
        command_methods.each do |method|
            puts method
            if self.help(method)
                #puts $main.help(method.to_sym)
                event = {'msg' => '/'+method[4..-1]+' : '+self.help(method).to_s}
                @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
            end
        end
            
    end
    
    #~ def cmd_help(arguments, channel, network, presence)
        #~ helptext = "This is a list of the supported commands and their parameters:

#~ /server <name>:<protocol>:<address>[:<port>] - Port is optional, irssi2 will use the defaults if its not specified. This command does NOT connect to the server, it merely defines the server so you can /connect to it.
#~ /connect <networkname> [<presence>] - Connect to the network, if no presence is defined it will use the default.
#~ /disconnect <network> [<presence>] - Disconnect from the network
#~ /networks - List all defined networks.
#~ /presences - List all defined presences.
#~ /channels - list all defined channels.
#~ /join <channel>
#~ /part <channel>
#~ /msg <user> <message>
#~ /quit - Quit rirc, but leave irssi2 running.
#~ /shutdown - Quit rirc and kill irssi2.
#~ /send <file> Sends a file to irssi2 - buggy.
#~ /whois <username>
#~ /help - Displays this message
        
#~ /raw <command> - Sends a raw command to irssi2, do NOT specify a tag.
#~ /ruby <command> - Sends a command to ruby's eval() function, if you break something using this, you get to keep all the pieces."
        
        #~ lines = helptext.split("\n")
        #~ lines.each do |line|
            #~ temp = {'msg' => line}
            #~ @serverlist.send_user_event(temp, EVENT_NOTICE)
        #~ end
    #~ end
        
end