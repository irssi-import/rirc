require 'socket'

class MPDPlay < Plugin
    def load
        $config['mpdformatstring'] = 'is listening to %A - %T [MPD]' unless $config['mpdformatstring']
        $config['mpdhost'] = 'localhost' unless $config['mpdhost']
        $config['mpdport'] = 6600 unless $config['mpdport']
        $config['mpdpass'] = '' unless $config['mpdpass']
        
        locale = self#we need a reference to the current location...
        
        help :cmd_np, "Display the currently playing song in MPD"
        add_method(self, Main, 'cmd_np') do |args, channel, network, presence|
            begin
                result = locale.query_mpd
            rescue IOError
                throw_error("MPD error: #{$!}")
                return
            else
                artist, title, album = result
                string = $config['mpdformatstring'].dup
                string.sub!('%A', artist)
                string.sub!('%T', title)
                string.sub!('%D', album)
                send_command('nowplaying', 'msg;mypresence='+presence+';network='+network.name+';channel='+channel.name+';msg='+escape(string)+';type=action') if channel and network
                @window.currentbuffer.send_user_event({'msg'=>string, 'type'=>'action'}, EVENT_USERMESSAGE)
            end
        end
        
        help :cmd_next, "Skip to next song in MPD"
        add_method(self, Main, 'cmd_next') do |args, channel, network, presence|
            begin
                result = locale.command_mpd('next')
            rescue IOError
                throw_error("MPD error: #{$!}")
                return
            end
        end
        
        help :cmd_prev, "Skip to previous song in MPD"
        add_method(self, Main, 'cmd_prev') do |args, channel, network, presence|
            begin
                result = locale.command_mpd('previous')
            rescue IOError
                throw_error("MPD error: #{$!}")
                return
            end
        end
        
        help :cmd_pause, "Toggle play/pause in MPD"
        add_method(self, Main, 'cmd_pause') do |args, channel, network, presence|
            begin
                result = locale.command_mpd('pause')
            rescue IOError
                throw_error("MPD error: #{$!}")
                return
            end
        end
    end
    
    def connect_mpd
        begin
            socket = TCPSocket.new($config['mpdhost'], $config['mpdport'])
        rescue Errno::ECONNREFUSED
            raise IOError, 'Failed to connect'
        end
        socket.recv(30)#grab the connect message
        if  !$config['mpdpass'].empty?
            socket.send('password '+ $config['mpdpass']+"\n", Socket::MSG_DONTROUTE)
            res = socket.recv(40)
            if res =~ /^ACK /
                raise IOError, 'Incorrect Password'
            end
        end
        return socket
    end
    
    def command_mpd(command)
        socket = connect_mpd
        socket.send(command+"\n", Socket::MSG_DONTROUTE)
        res = socket.recv(300)
        socket.close
        return res
    end
    
    def query_mpd
        socket = connect_mpd
        socket.send("currentsong\n", Socket::MSG_DONTROUTE)
        res = socket.recv(300)
        artist = 'Unknown'
        album = 'Unknown'
        title = 'Unknown'
        
        res.split("\n").each do |line|
            if line =~ /^Artist: (.+)/
                artist = $1
            elsif line =~ /^Album: (.+)/
                album = $1
            elsif line =~ /^Title: (.+)/
                title = $1
            end
        end
        
        socket.close
        
        return [artist, title, album]
    end
    
    def configure
        return [{'type' => String, 'name' => 'mpdformatstring',
        'value' => $config['mpdformatstring'], 'description' => 'Format string'},
        {'type' => String, 'name' => 'mpdhost', 
        'value' => $config['mpdhost'], 'description' => 'MPD host'},
        {'type' => Integer, 'name' => 'mpdport', 
        'value' => $config['mpdport'], 'description' => 'MPD port'},
        {'type' => String, 'name' => 'mpdpass', 
        'value' => $config['mpdpass'], 'description' => 'MPD password'}
        ]
    end
end

mpdplay = MPDPlay.new
Plugin.register(mpdplay)