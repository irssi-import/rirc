module CommandParser    
    def command_parse(message, channel, network, presence)
		command, arguments = message.split(' ', 2)
		
		arguments = '' if ! arguments
        
        if command[0].chr == '/'
            cmd = command[1, command.length]
        end
        
        if cmd and self.respond_to?('cmd_'+cmd)
            self.send('cmd_'+cmd, arguments, channel, network, presence)
        else
            #its not a command, treat as a message
            if network
                messages = message.split("\n")
                messages.each { |message|
                    
                    if channel.class == ChannelBuffer
                        send_command('message'+rand(100).to_s, 'msg;network='+network+';channel='+channel.name+';msg='+escape(message)+";presence="+presence)
                    elsif channel.class == ChatBuffer
                        send_command('message'+rand(100).to_s, 'msg;network='+network+';nick='+channel.name+';msg='+escape(message)+";presence="+presence)
                    end
                    line = {}
                    line['nick'] = presence
                    line['msg'] = message
                    #~ time = Time.new
                    #~ time = time - @drift if $config['canonicaltime'] == 'server'
                    #~ line['time'] = time
                    #@serverlist[network, 'vag'].users[presence].lastspoke= time.to_i
                    @window.currentbuffer.send_user_event(line, USERMESSAGE)			}
            elsif !network
                #line = {}
                line = {'err' => 'Invalid server command'}
                #~ time = Time.new
                #~ time = time - @drift if $config['canonicaltime'] == 'server'
                #~ line['time'] = time
                @window.currentbuffer.send_user_event(line, ERROR)
            end
        end
    end
    
    #~ def cmd_channel(arguments, channel, network, presence)
        #~ channel_add(network, presence, arguments)
    #~ end
    
    #/join command
    def cmd_join(arguments, channel, network, presence)
        return unless network
        send_command('join', 'channel join;network='+network+';presence='+presence+';channel='+arguments)
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
        
        presence_add(network, presence)
        
        network_connect(network, presence)
    end
    
    #/disconnect command
    def cmd_disconnect(arguments, *args)
        servername, presence = arguments.split(' ', 2)
        
        if presence
        elsif @window.currentbuffer.server.name == servername
            presence = @window.currentbuffer.server.presence
        else
            results = @serverlist.get_network_by_name(servername)
            
            results.delete_if {|server| !server.connected}
            
            if results.length == 1
                presence = results[0].presence
            elsif results.length > 1
                line = {'err' => 'Multiple networks named '+servername+' please specify a presence'}
                @window.currentbuffer.send_user_event(line, ERROR)
            else
                line = {'err' => 'No network names '+servernames}
                @window.currentbuffer.send_user_event(line, ERROR)
            end
        end
        
        if presence and servername
            send_command('disconnect'+servername, "presence disconnect;network="+servername+";presence="+presence)
        end
    end
    
    #/part command
    def cmd_part(arguments, channel, network, presence)
        arguments = arguments.split(' ')
        if arguments[0]
            send_command('part', "channel part;network="+network+";presence="+$config['presence']+";channel="+arguments[0])
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
        if arguments =~ /^(.+) (.+)( (.+)|)$/
        pub = $1
        priv = $2
        pass = $3
        if pub and priv
            key_pub = pub.to_s.sub('~', ENV['HOME'])
            key_priv = priv.to_s.sub('~', ENV['HOME'])
            
            if File.file?(key_pub) and File.file?(key_priv)
                @keys[$config['presence']] = {'silc_pub' => IO.read(key_pub),
                                            'silc_priv' => Base64.encode64(IO.read(key_priv))}
                @keys[$config['presence']]['silc_pass'] = pass if pass.length > 0
            else
                puts 'file not found'
            end
        end
        end
    end
    
    #/send command
    def cms_send(arguments, channel, network, presence)
        if arguments[0] == '~'[0]
            arguments.sub!('~', ENV['HOME'])#expand ~
        end
        name, path = arguments.reverse.split('/', 2)
        name.reverse!
        path = '' if !path
        path.reverse!
        @filedescriptors[name] = File.open(arguments, 'r') # create a file descriptor with a key the same as the filename sent to server
        send_command('file send '+name, 'file send;resume;name='+name+';size='+File.size(arguments).to_s)
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
        send_command('nick'+name, 'presence change;network='+network+';presence='+presence+';new_name='+name)
    end
    
    #/whois command
    def cmd_whois(arguments, channel, network, presence)
        name, bleh = arguments.split(' ', 2)
        send_command('whois'+name, 'presence status;network='+network+';presence='+presence+';name='+name)
    end
    
    #/msg command
    def cmd_msg(arguments, channel, network, presence)
        arguments = arguments.split(' ', 2)
        if arguments[0] and arguments[1]
            messages = arguments[1].split("\n")
            messages.each { |message|
                send_command('msg'+rand(100).to_s, 'msg;network='+network+';nick='+arguments[0]+';msg='+message+";presence="+presence)
            }
        else
            line ={'err' => '/msg requires a username and a message'}
            #~ time = Time.new
            #~ time = time - @drift if $config['canonicaltime'] == 'server'
            #~ line['time'] = time
            @window.currentbuffer.send_user_event(line, ERROR)
        end
    end
    
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
    
    def cmd_help(arguments, channel, network, presence)
        helptext = "This is a list of the supported commands and their parameters:

/server <name>:<protocol>:<address>[:<port>] - Port is optional, irssi2 will use the defaults if its not specified. This command does NOT connect to the server, it merely defines the server so you can /connect to it.
/connect <networkname> [<presence>] - Connect to the network, if no presence is defined it will use the default.
/disconnect <network> [<presence>] - Disconnect from the network
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