class Configuration
	def initialize
		#set some defaults... probably too soon be overriden by the user's config, but you gotta start somewhere :P
		@values = {}
        16.times do |x|
            @values['color'+x.to_s] = Gdk::Color.new(0, 0, 0)
        end
		@values['color0'] = Gdk::Color.new(62168, 16051, 16051)
		@values['color1'] = Gdk::Color.new(0, 47254, 11392)
		@values['color2'] = Gdk::Color.new(0, 28332, 65535)
		@values['color3'] = Gdk::Color.new(65535, 65535, 0)
		@values['color4'] = Gdk::Color.new(65535, 0, 65535)
		@values['color5'] = Gdk::Color.new(0, 65535, 65535)
		
		@values['backgroundcolor'] = Gdk::Color.new(65535, 65535, 65535)
		@values['foregroundcolor'] = Gdk::Color.new(0, 0, 0)
		@values['selectedbackgroundcolor'] = Gdk::Color.new(13208, 44565, 62638)
		@values['selectedforegroundcolor'] = Gdk::Color.new(65535, 65535, 65535)

		@values['neweventcolor'] = Gdk::Color.new(45535, 1000, 1000)
		@values['newmessagecolor'] = Gdk::Color.new(65535, 0, 0)
		@values['highlightcolor'] = Gdk::Color.new(0, 0, 65535)
		
		@statuscolors = [Gdk::Color.new(0, 0, 0), @values['neweventcolor'], @values['newmessagecolor'], @values['highlightcolor']]
		
		@values['usetimestamp'] = true
		@values['timestamp'] = "[%H:%M]"
		@values['message'] = "%2<%2%u%2>%2 %m"
		@values['usermessage'] = "%4<%4%u%4>%4 %m"
		@values['action'] = "%1*%1 %u %m"
		@values['notice'] = "-%1--%1 %m"
		@values['error'] = "%0***%0 %m"
		@values['join'] = "-%1->%1 %u (%1%h%1) has joined %c"
		@values['userjoin'] = "-%1->%1 You are now talking on %c"
		@values['part'] = "<%1--%1 %u (%1%h%1) has left %c (%r)"
		@values['userpart'] = "<%1--%1 You have left %c"
		@values['whois'] = "%2[%2%n%2]%2 %m"
        @values['topic_change'] = '-%1--%1 Topic set to %6%t%6 by %6%u%6'
        @values['topic'] ='-%1--%1 Topic for %6%c%6 is %6%t%6'
		@values['topic_setby'] = '-%1--%1 Topic for %6%c%6 set by %6%u%6 at %6%a%6'
        @values['add_mode'] = '-%1--%1 %s gave %m to %u'
        @values['remove_mode'] = '-%1--%1 %s removed %m from %u'
        
		@values['linkclickaction'] = 'firefox -remote "openURL(%s,new-tab)"'
		
		@serverbuttons = true
		
		@values['channellistposition'] = 'bottom'
		
		@values['commandbuffersize'] = 10
		
		@values['presence'] = 'irssi2'
		
		@values['canonicaltime'] = 'client'
		@values['tabcompletesort'] = 'activity'
        
        @values['main_font'] = 'monospace 9'
        
        @values['number_tabs'] = true
		
		@oldvalues = {}
	end
	
	#converts status into a color
	def getstatuscolor(status)
		return @statuscolors[status]
	end
	
	#retrieves a value
	def [](value)
		return get_value(value)
	end
	
	#why is this here?
	def get_all_values
		return @values
	end
	
	#another mystery function
	def get_value(value)
		if @values.values
			return @values[value]
		else
			return false
		end
	end
	
	#set a config value
	def set_value(key, value)
		@values[key] = value
	end
	
	#send the config to irssi2
	def send_config
		cmdstring = ''
		
		@values.each do |k, v|
			value = encode_value(v)
			if @oldvalues[k] != value or  !@oldvalues[k]
				cmdstring += ';rirc_'+k+'='+value if k and value
				puts k+" HAS changed"
			else
			end
		end
		
		if cmdstring == ''
			puts 'no changes'
			return
		else
			cmdstring = 'config set'+cmdstring
		end
		
		$main.send_command('sendconfig', cmdstring)
	end
	
	#request the config from irssi2
	def get_config
		$main.send_command('getconfig', 'config get;*')
		while $main.replies['getconfig']
			sleep 1
		end
	end
	
	#encode the values so they can be stored by irssi2
	def encode_value(value)
		if value.class == Gdk::Color
			colors = value.to_a
			return 'color:'+colors[0].to_s+':'+colors[1].to_s+':'+colors[2].to_s
		elsif value.class == String
			return value
		elsif value == true
			return 'true'
		elsif value == false
			return 'false'
		else
			return value.to_s
		end
	end
	
	#decode values retrieved from irssi2
	def decode_value(value)
		if value =~ /^color\:(\d+)\:(\d+)\:(\d+)$/
			return Gdk::Color.new($1.to_i, $2.to_i, $3.to_i)
		elsif value == 'true'
			return true
		elsif value == 'false'
			return false
		else
			return value
		end
	end
	
	#parse the configs retrieved from irssi2
	def parse_config(reply)
		reply.lines.each do |line| 
			if line['key'] and line['value']
				value = decode_value(line['value'])
				@values[line['key'].sub('rirc_', '')] = value
			end
		end
		
		create_config_snapshot
	end
	
	#create a copy of the config so we can compare for changes
	def create_config_snapshot
		@values.each do |k, v|
			@oldvalues[k.deep_clone] = encode_value(v)
		end
	end
		
end