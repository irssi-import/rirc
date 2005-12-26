require 'socket'

class MPDPlay < Plugin
    def load
        $config['mpdformatstring'] = 'is listening to %A - %T [MPD]' unless $config['mpdformatstring']
        $config['mpdhost'] = 'localhost' unless $config['mpdhost']
        $config['mpdport'] = 6600 unless $config['mpdport']
        $config['mpdpass'] = '' unless $config['mpdpass']
        
        locale = self
        
        add_method(self, Main, 'cmd_np') do |args, channel, network, presence|
            break unless channel and network
            if result = locale.query_mpd
                artist, title, album = result
                string = $config['mpdformatstring'].dup
                string.sub!('%A', artist)
                string.sub!('%T', title)
                string.sub!('%D', album)
                #~ string.sub!('%S', (pos/60.0).to_s)
                #~ string.sub!('%E', (time/60.0).to_s)
                #puts string
                send_command('nowplaying', 'msg;mypresence='+presence+';network='+network.name+';channel='+channel.name+';msg='+escape(string)+';type=action')
                @window.currentbuffer.send_user_event({'msg'=>string, 'type'=>'action'}, EVENT_USERMESSAGE)
            else
                throw_error('Failed to connect to MPD, please check your connection and password configuration and that MPD is running')
            end
        end
    end
    
    def query_mpd
        begin
            socket = TCPSocket.new($config['mpdhost'], $config['mpdport'])
        rescue Errno::ECONNREFUSED
            return
        end
        socket.recv(30)#grab the connect message
        if  !$config['mpdpass'].empty?
            socket.send('password '+ $config['mpdpass']+"\n", Socket::MSG_DONTROUTE)
            res = socket.recv(40)
            if res =~ /^ACK /
                puts 'connection failed'
                return
            end
        end
        socket.send("currentsong\n", Socket::MSG_DONTROUTE)
        res = socket.recv(300)
        artist = 'Unknown'
        album = 'Unknown'
        title = 'Unknown'
        #~ pos = 0
        #~ time = 0
        
        res.split("\n").each do |line|
            if line =~ /^Artist: (.+)/
                artist = $1
            elsif line =~ /^Album: (.+)/
                album = $1
            elsif line =~ /^Title: (.+)/
                title = $1
            #~ elsif line =~ /^Pos: (.+)/
                #~ pos = $1.to_i
            #~ elsif line =~ /^Time: (.+)/
                #~ time = $1.to_i
            end
        end
        
        socket.close
        
        return [artist, title, album]#, pos, time]
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