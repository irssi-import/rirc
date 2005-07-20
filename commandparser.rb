module CommandParser    
    def command_parse(message, network, presence, channel)

        if network and !network.loggedin
            throw_message('buffering command '+message)
            network.bufferedcommands.push(message)
            return
        end
        		
        #arguments ||= ''
        #command ||= ''
        
		#command, arguments = message.split(' ', 2)
        if /^(\/\w+)(?: (.+)|)/.match(message)
            command = $1
            arguments = $2
        end
        
        #puts '"'+command+'"' if command
        #puts '"'+arguments+'"' if arguments
        
        if command and command[0].chr == '/'
            cmd = command[1, command.length].downcase
        #~ else
            #~ cmd = 'message'
            #~ arguments = message
        end
        
        if cmd and self.respond_to?('cmd_'+cmd)
            res = callback('cmd_'+cmd, arguments, channel, network, presence)
            return if res === true
           # puts res
            #if res.class == Array and res.length > 0
                self.send('cmd_'+cmd, *res)
            #else
            #    self.send('cmd_'+cmd, arguments, channel, network, presence)
            #end
        else
            res = callback('cmd_message', message, channel, network, presence)
            self.send('cmd_message', *res)
        end
    end
    
    #~ def cmd_channel(arguments, channel, network, presence)
        #~ channel_add(network, presence, arguments)
    #~ end
    
    def cmd_message(message, channel, network, presence)
        #its not a command, treat as a message
        if network
            #puts message
            messages = message.split("\n")
            messages.each { |message|
                
                if channel.class == ChannelBuffer
                    send_command('message'+rand(100).to_s, 'msg;network='+network.name+';channel='+channel.name+';msg='+escape(message)+";presence="+presence)
                elsif channel.class == ChatBuffer
                    send_command('message'+rand(100).to_s, 'msg;network='+network.name+';nick='+channel.name+';msg='+escape(message)+";presence="+presence)
                end
                line = {}
                line['nick'] = presence
                line['msg'] = message
                @window.currentbuffer.send_user_event(line, USERMESSAGE)			}
        elsif !network
            #line = {}
            line = {'err' => 'Invalid server command'}
            @window.currentbuffer.send_user_event(line, ERROR)
        end
    end
    
    #/join command
    def cmd_join(arguments, channel, network, presence)
        return unless network and arguments
        send_command('join', 'channel join;network='+network.name+';presence='+presence+';channel='+arguments)
    end
    
    #/server command
    def cmd_server(arguments, channel, network, presence)
        if arguments  =~ /^([a-zA-Z0-9_\-]+):([a-zA-Z]+):([a-zA-Z0-9_.\-]+)(?:$|:(\d+))/
        network_add($1, $2, $3, $4)
        end
    end
    
    #/connect command
    def cmd_connect(arguments, channel, network, presence)
        network, presence = arguments.split(' ', 2)
        
        unless presence
            presence = $config['presence']
        end
        
        if presence_add(network, presence)
            network_connect(network, presence)
        end
    end
    
    #/disconnect command
    def cmd_disconnect(arguments, *args)
        servername, presence = arguments.split(' ', 2)
        
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
                line = {'err' => 'Multiple networks named '+servername+' please specify a presence'}
                @window.currentbuffer.send_user_event(line, ERROR)
            else
                line = {'err' => 'No network names '+servernames}
                @window.currentbuffer.send_user_event(line, ERROR)
            end
        end
        
        if presence and servername
            send_command('disconnect'+servername, "presence disconnect;network="+servername+";presence="+presence)
            server = @serverlist[servername, presence]
            server.disconnect
            #
            #server.close if server
        end
    end
    
    #/part command
    def cmd_part(arguments, channel, network, presence)
        arguments = arguments.split(' ')
        if arguments[0]
            send_command('part', "channel part;network="+network.name+";presence="+presence+";channel="+arguments[0])
        else
            #line = {}
            line = {'err' => 'Part requires a channel argument'}
            #~ time = Time.new
            #~ time = time - @drift if $config['canonicaltime'] == 'server'
            #~ line['time'] = time
            @window.currentbuffer.send_user_event(line, ERROR)
        end
    end
    
    #/quit command
    def cmd_quit(arguments, channel, network, presence)
        send_command('quit', 'quit')
        Gtk.main_quit
        quit(false)
    end
    
    #/shutdown command
    def cmd_shutdown(arguments, channel, network, presence)
        send_command('shutdown', 'shutdown')
        Gtk.main_quit
        quit(false)
    end
    
    #/silckey command
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
    def cmd_ruby(arguments, channel, network, presence)
        puts 'possibly evil ruby code inputted, blindly executing'
        eval(arguments)
    end
    
    #/raw command
    def cmd_raw(arguments, channel, network, presence)
        output = {}
        output['msg'] = 'Sent raw command "'+arguments+'" to irssi2 directly'
        @serverlist.send_event(output, NOTICE)
        send_command('raw', arguments)
    end
    
    #/nick command
    def cmd_nick(arguments, channel, network, presence)
        name, bleh = arguments.split(' ', 2)
        send_command('nick'+name, 'presence change;network='+network.name+';presence='+presence+';new_name='+name)
    end
    
    #/whois command
    def cmd_whois(arguments, channel, network, presence)
        if arguments
            name, bleh = arguments.split(' ', 2)
        else
            name = network.username
        end
        send_command('whois'+name, 'presence status;network='+network.name+';presence='+presence+';name='+name)
    end
    
    #/msg command
    def cmd_msg(arguments, channel, network, presence)
        arguments = arguments.split(' ', 2)
        if arguments[0] and arguments[1]
            messages = arguments[1].split("\n")
            messages.each { |message|
                send_command('msg'+rand(100).to_s, 'msg;network='+network.name+';nick='+arguments[0]+';msg='+message+";presence="+presence)
            }
        else
            line ={'err' => '/msg requires a username and a message'}
            #~ time = Time.new
            #~ time = time - @drift if $config['canonicaltime'] == 'server'
            #~ line['time'] = time
            @window.currentbuffer.send_user_event(line, ERROR)
            
        end
    end
    
    #~ def cmd_me(message, channel, network, presence)
       #~ send_command('message'+rand(100).to_s, 'msg;network='+network.name+';channel='+channel.name+';msg='+escape(message)+";presence="+presence+';type=action')
       #~ #user
    #~ end
    
    def cmd_networks(*args)
        lines = ['Defined networks:']
        @networks.each {|network| lines.push(network)}
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, NOTICE)
        end
    end
    
    def cmd_presences(*args)
        lines = ['Defined Presences:']
        
        @serverlist.servers.each do |server|
            network, presence = server.getnetworkpresencepair
            if server.connected
                lines.push(network+' - '+presence+' - Connected')
            else
                lines.push(network+' - '+presence)
            end
        end
        
        lines.push(' ')
        
        lines.each do |line|
            event = {'msg' => line}
            @window.currentbuffer.send_user_event(event, NOTICE)
        end
        
        #@presences.each {|presence| lines.push(presence[0]+' - '+presence[1])}
    end
    
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
            @window.currentbuffer.send_user_event(event, NOTICE)
        end
    end
    
    def cmd_load(arguments, channel, network, presence)
        plugin_load(arguments)
    end
    
    def cmd_unload(arguments, *args)
        if plugin = Plugin.lookup(arguments)
            Plugin.unregister(plugin)
        else
         throw_error('no plugin found called '+arguments)
        end
    end
    
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
            @window.currentbuffer.send_user_event(event, NOTICE)
        end
    end
    
    def cmd_spam(arguments, *args)
        count = 500
        if arguments =~ /[\d]+/
            count = arguments.to_i
        end
        
        count.times do |i|
            event = {'msg' => 'This is testing spam'}
            @window.currentbuffer.send_user_event(event, NOTICE)
        end
    end
    
    def cmd_help(arguments, channel, network, presence)
        helptext = "This is a list of the supported commands and their parameters:

/server <name>:<protocol>:<address>[:<port>] - Port is optional, irssi2 will use the defaults if its not specified. This command does NOT connect to the server, it merely defines the server so you can /connect to it.
/connect <networkname> [<presence>] - Connect to the network, if no presence is defined it will use the default.
/disconnect <network> [<presence>] - Disconnect from the network
/networks - List all defined networks.
/presences - List all defined presences.
/channels - list all defined channels.
/join <channel>
/part <channel>
/msg <user> <message>
/quit - Quit rirc, but leave irssi2 running.
/shutdown - Quit rirc and kill irssi2.
/send <file> Sends a file to irssi2 - buggy.
/whois <username>
/help - Displays this message
        
/raw <command> - Sends a raw command to irssi2, do NOT specify a tag.
/ruby <command> - Sends a command to ruby's eval() function, if you break something using this, you get to keep all the pieces."
        
        lines = helptext.split("\n")
        lines.each do |line|
            temp = {'msg' => line}
            @serverlist.send_user_event(temp, NOTICE)
        end
    end
        
end