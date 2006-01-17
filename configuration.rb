class Configuration
    attr_reader :values, :defaults
    def initialize
        #set some defaults... probably too soon be overriden by the user's config, but you gotta start somewhere :P
        @values = YAML.load_file('themes/default.yaml')
 
        #store defaults
        @defaults = duplicate_config
        
        @statuscolors = [@values['defaultcolor'], @values['neweventcolor'], @values['newmessagecolor'], @values['highlightcolor']]
 
        @oldvalues = {}
    end
    
    def dump
        File.open('themes/default.yaml', "w+") {|f| YAML.dump(@values, f)}
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
        if @values[value]
            return @values[value]
        else
            return false
        end
    end
 
    def []=(key, value)
        value = decode_value(value) if value.class == String
        @values[key] = value
        #update the color array on the off-chance we changed it :(
        @statuscolors = [@values['defaultcolor'], @values['neweventcolor'], @values['newmessagecolor'], @values['highlightcolor']]
    end
 
    #send the config to irssi2
    def changes
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
        
        cmdstring
        #$main.send_command('sendconfig', cmdstring)
    end
 
    #request the config from irssi2
    #~ def get_config
        #~ $main.send_command('getconfig', 'config get;*')
        #~ while $main.replies['getconfig']
            #~ sleep 1
        #~ end
    #~ end
 
    #encode the values so they can be stored by irssi2
    #this function recursively encodes arrays in hashes to handle n dimensional structures
    def encode_value(value)
        if value.class == Color
            colors = value.to_a[0..2]
            'color{' + colors.map {|color| "#{color}" }.join(":")+'}'
        elsif value.class == Array
            'array{' + value.map {|v| encode_value(v)}.join(":")+'}'
        elsif value.class == Hash
            'hash{' + value.map {|k, v| encode_value(k) + ':' + encode_value(v) }.join("::")+'}'
        elsif value =~ /^(color|array|hash)\:(\d+)\:(\d+)\:(\d+)$/
            return value
        elsif value.nil? #we don't want nil being encoded to "", this fux0rs arrays...
            return 'nil'
        elsif value.respond_to? :to_s #everythign else gets converted to a string
            return value.to_s.gsub(':', '\,')
        else #if we can't convert it to a string, don't store it
            return nil
        end
    end
 
    #decode values retrieved from irssi2
    #recursively decodes arrays and hashes, gets a bit hairy though...
    def decode_value(value)
        value = unescape(value) if value
        if value == 'true'
            return true
        elsif value == 'false'
            return false
        elsif value == 'nil'
            return nil
        else
            if value.nil?
                return nil
            end
            values = value.split('{', 2)
            values[1].chomp!('}') if values[1]
            if values[0] == 'array'
                x = []
                #~ values[1].split(':').each do |v|
                    #~ if v =~ /^(array|hash|color)\{/
                        #~ puts v
                    #~ end
                    #~ x.push(decode_value(v))
                #~ end
                string = values[1]
                while string
                    #check if the next part of the source string is an object
                    if string =~ /^((?:array|hash|color)\{.+?\}(?:\:|$))/
                        match = $1
                        #trim the trailing : and decode it and then push it onto the array
                        x.push(decode_value($1.chomp(':')))
                        #remove the match from the source string and skip to the next loop iteration
                        string.slice!(match)
                        next
                    end
                    part, string = string.split(':', 2)
                    x.push(decode_value(part)) if part
                end
                x
            elsif values[0] == 'hash'
                x = {}
                #~ values[1].split('::').each do |y|
                    #~ k, v = y.split(':')
                    #~ x[decode_value(k)] = decode_value(v)
                #~ end
                string = values[1]
                while string
                    #check for an object
                    if string =~ /^((?:array|hash|color)\{.+?\}.+?(?:\:\:|\}$))/
                        #store the match in a variable so it doesn't get clobbered later on
                        match = $1
                        #heh, trim the trailing :: and split by the last :
                        key, value = $1.chomp('::').reverse.split(':', 2).map{|y| y.reverse}.reverse
                        #stick it in the hash
                        x[decode_value(key)] = decode_value(value)
                        #remove the match from the string
                        string.slice!(match)
                        next
                    end
                    part, string = string.split('::', 2)
                    if part
                        k, v = part.split(':', 2)
                        x[decode_value(k)] = decode_value(v)
                    end
                end
                x
            elsif values[0] == 'color'
                r, g, b = values[1].split(':').map {|x| x.to_i }
                Color.new(r, g, b)
            elsif value.numeric?
                if value.include? '.'
                    value.to_f
                else
                    value.to_i
                end
            else
                value.gsub('\,', ':')
            end
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
            @oldvalues[k.dup] = encode_value(v)
        end
    end
 
    def update_snapshot(hash)
        hash.each{|k,v| hash[k] = encode_value(v)}
        @oldvalues.merge!(hash)
    end
 
    def duplicate_config
        vals = {}
        @values.each do |k, v|
            vals[k.dup] = decode_value(encode_value(v))
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
            return @values[name].dup #don't escape_xml here
        else
            return ''
        end
    end
end