class Configuration
    attr_reader :defaults
	def initialize
		#set some defaults... probably too soon be overriden by the user's config, but you gotta start somewhere :P
		@values = {}
        16.times do |x|
            @values['color'+x.to_s] = Gdk::Color.new(0, 0, 0)
        end
        @values['defaultcolor'] = Gdk::Color.new(0, 0, 0)
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
        
        @values['scw_even'] = Gdk::Color.new(65535, 65535, 65535)
        @values['scw_odd'] = Gdk::Color.new(50176, 50176, 50176)
        @values['scw_lastread'] = Gdk::Color.new(65535, 59940, 59940)
		@values['scw_prelight'] = Gdk::Color.new(62168, 16051, 16051)
        @values['scw_align_presences'] = false
        
		@statuscolors = [@values['defaultcolor'], @values['neweventcolor'], @values['newmessagecolor'], @values['highlightcolor']]
		
		@values['usetimestamp'] = true
        @values['show_usermode'] = true
        @values['pad_usermode'] = false
		@values['timestamp'] = "[%H:%M]"
        @values['usernameformat'] = "%C4<%C4%u%C4>%C4"
		@values['message'] = "%m"
        @values['otherusernameformat'] = "%C2<%C2%u%C2>%C2"
		@values['usermessage'] = "%m"
		@values['action'] = "%C1*%C1 %u %m"
		@values['notice'] = "-%C1--%C1 %m"
		@values['error'] = "%C0***%C0 %m"
		@values['join'] = "-%C1->%C1 %u (%C1%h%C1) has joined %c"
		@values['userjoin'] = "-%C1->%C1 You are now talking on %c"
		@values['part'] = "<%C1--%C1 %u (%C1%h%C1) has left %c (%r)"
		@values['userpart'] = "<%C1--%C1 You have left %c"
		@values['whois'] = "%C2[%C2%n%C2]%C2 %m"
        @values['topic_change'] = '-%C1--%C1 Topic set to %C6%t%C6 by %C6%u%C6'
        @values['topic'] = '-%C1--%C1 Topic for %C6%c%C6 is %C6%t%C6'
		@values['topic_setby'] = '-%C1--%C1 Topic for %C6%c%C6 set by %C6%u%C6 at %C6%a%C6'
        @values['add_mode'] = '-%C1--%C1 %s gave %m to %u'
        @values['remove_mode'] = '-%C1--%C1 %s removed %m from %u'
        @values['nickchange'] = '-%C1--%C1 %u is now known as %n'
        @values['usernickchange'] = '-%C1--%C1 You are now known as %n'
        
		@values['linkclickaction'] = 'firefox "%s"'
        
        @values['tabcompletesuffix'] = ';'
        @values['tabonmsg'] = false
		
		@serverbuttons = true
		
		@values['tablistposition'] = 'bottom'
        @values['tablisttype'] = 'button'
        @values['tabstructure'] = 'hierarchical'
        @values['tabsort'] = 'Case Insensitive'
		
		@values['commandbuffersize'] = 10
		
		@values['presence'] = 'irssi2'
		
		@values['canonicaltime'] = 'client'
		@values['tabcompletesort'] = 'activity'
        
        @values['main_font'] = 'monospace 9'
        
        @values['numbertabs'] = true
        
        @values['plugins'] = []
        
        @values['aliases'] = {}
        
        @values['keybindings'] = {}
        
        @values['keybindings']['Alt-l'] = 'open_linkwindow'
        
        #~ 9.times do |i|
            #~ @values['keybindings']['Alt-'+i.to_s] = 'switchtab('+i.to_s+')'
        #~ end
        
        #~ j = 10
        #~ %w{0 q w e r t y u i o p}.each do |c|
            #~ @values['keybindings']['Alt-'+c] = 'switchtab('+j.to_s+')'
            #~ j += 1
        #~ end
        
        #store defaults
        @defaults = duplicate_config
		
		@oldvalues = {}
	end
    
    def gettabmodelconfig
            
        if @values['tabsort'] == 'case sensitive'
            sort = SENSITIVE
        elsif @values['tabsort'] == 'case sensitive no hash'
            sort = INSENSITIVE_NOHASH
        elsif @values['tabsort'] == 'case sensitive no hash'
            sort = SENSITIVE_NOHASH
        else
            sort = INSENSITIVE
        end
            
        if @values['tabstructure'] == 'flat'
            structure = FLAT
        else
            structure = HIERARCHICAL
        end
        
        return [structure, sort]
    end
	
	#converts status into a color
	def getstatuscolor(status)
        if status.nil?
            return @statuscolors[0]
        end
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
        value = decode_value(value) if value.class == String
		@values[key] = value
        
        #update the color array on the off-chance we changed it :(
        @statuscolors = [@values['defaultcolor'], @values['neweventcolor'], @values['newmessagecolor'], @values['highlightcolor']]
	end
	
	#send the config to irssi2
	def send_config
		cmdstring = ''
		
        configs = []
        
		@values.each do |k, v|
			value = encode_value(v)
			if @oldvalues[k] != value or  !@oldvalues[k]
                key = 'rirc_'+k unless k['rirc_']
                
				configs.push(key+'='+escape(value)) if k and value
				puts k+" HAS changed"
			else
			end
		end
		
		if configs.length == 0
			puts 'no changes'
			return
		else
			cmdstring = 'config set;'+configs.join(';')
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
        elsif value.class == Array
            x = []
            value.each do |v|
                x.push(v.gsub(':', '\,'))
            end
            return 'array:'+x.join(':')
        elsif value.class == Hash
            x = []
            value.each do |k, v|
                x.push(k.gsub(':', '\,')+':'+v.gsub(':', '\,'))
            end
            return 'hash:'+x.join('::')
        elsif value =~ /^(color|array|hash)\:(\d+)\:(\d+)\:(\d+)$/
            return value
		elsif value.class == TrueClass
			return 'true'
		elsif value.class == FalseClass
			return 'false'
        elsif value.class == String
            return value
        elsif value.class == Fixnum
            return value.to_s
		else
            puts 'cannot dump unknown object'
            #return YAML::dump(value).gsub("\n", "\\\\\\n")
		end
	end
	
	#decode values retrieved from irssi2
	def decode_value(value)
        value = unescape(value) if value
		if value =~ /^color\:(\d+)\:(\d+)\:(\d+)$/
			return Gdk::Color.new($1.to_i, $2.to_i, $3.to_i)
        elsif value =~ /^array\:(.*?)$/
            puts 'array'
            x = []
            $1.split(':').each do |v|
                x.push(v.gsub('\,', ':'))
            end
            return x
        elsif value =~ /^hash\:(.*?)$/
            puts 'hash'
            x = {}
            $1.split('::').each do |y|
                #x.push(v.gsub('\,', ':'))
                k, v = y.split(':')
                x[k.gsub('\,', ':')] =v.gsub('\,', ':')
            end
            return x
		elsif value == 'true'
			return true
		elsif value == 'false'
			return false
		else
            if(value[0,3] == '---')#check if its YAML
                begin
                    value = YAML::load(value.gsub("\\n", "\n"))
                rescue ArgumentError
                end
            end
            value.gsub!('\"', '"') if value.class == String
            
            if value =~ /^color\:(\d+)\:(\d+)\:(\d+)$/
                return Gdk::Color.new($1.to_i, $2.to_i, $3.to_i)
            end
			return value
		end
	end
	
	#parse the configs retrieved from irssi2
	def parse_config(reply)
		reply.lines.each do |line| 
			if line['key'] and line['value']
				value = decode_value(line['value'])
				@values[line['key'].sub('rirc_', '')] = value
                #puts line['key'].sub('rirc_', '')+'=>'+value.to_s
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
    
    def update_snapshot(hash)
        hash.each{|k,v| hash[k] = encode_value(v)}
        @oldvalues.merge!(hash)
    end
    
    def duplicate_config
        vals = {}
		@values.each do |k, v|
			vals[k.deep_clone] = decode_value(encode_value(v))
		end
        vals
    end
    
    def revert_to_defaults
        @values = {}
        @defaults.each do |k,v|
            @values[k] = v
        end
    end
		
    def get_pattern(name)
        if @values[name].class == String
            return @values[name].deep_clone #don't escape_xml here
        else
            return ''
        end
    end
end