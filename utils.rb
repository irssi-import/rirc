class String
    def numeric?
        if to_i == 0 and self != '0'
            return false
        end
        true
    end
end

class Color
    def initialize(r, g, b)
        @r, @g, @b = r, g, b
    end
    
    def to_a
        [@r, @g, @b]
    end
    
    def to_hex
        hex = '#'
        to_a.each do |c|
            e = c >> 8
            d = e.to_s(16)
            if d.length == 1
                d = '0'+d
            end
            hex += d
        end
        hex
    end
    
    def to_256
        res = []
        to_a.each do |c|
            t = c >> 8
            res << t
        end
        return res
    end
    
    def self.hex_to_a(string)
        r = string[0, 2].hex
        g = string[1, 2].hex
        b = string[4, 2].hex
        [r,g,b]
    end
    
    def self.a_to_hex(a)
        puts a.class
        res = ''
        a.each do |o|
            o = 255 if o > 255
            o = o.to_s(16)
            if o.length == 1
                o = '0'+o
            end
            res << o
        end
        res
    end
end

def duration(seconds, precision=2)
    
    if seconds < 0
        seconds *= -1
        negative = true
    end
    
    t = Time.at(seconds)
    t.gmtime
    
    seconds = t.strftime('%S').to_i
    minutes = t.strftime('%M').to_i
    hours = t.strftime('%H').to_i
    days = (t.strftime('%j').to_i)-1
    years = (t.strftime('%Y').to_i) - (Time.at(0).gmtime.strftime('%Y').to_i)
    
    stuff = []
    
    stuff.push(seconds.to_s+" Second#{'s' if seconds > 1}")
    stuff.push( minutes.to_s+" Minute#{'s' if minutes > 1}")
    stuff.push(hours.to_s+" Hour#{'s' if hours > 1}")
    stuff.push(days.to_s+" Day#{'s' if days > 1}") 
    stuff.push(years.to_s+" Year#{'s' if years > 1}") 
    
    stuff.reverse!
    
    result = stuff[0, precision].join(' ')
	
    result = ' - '+result if negative
	
    return result
end

#escape the string
def escape(string)
    result = string.gsub('\\', '\\\\\\')
    result.gsub!(';', '\\.')
    return result
end

#unescape the string
def unescape(string)
    result = string.gsub("\\.", "\\\\.")
    result.gsub!(%r{\\{1}\\\.}, '!.')
    result.gsub!('\\.', ';')
    result.gsub!('!.', '\\.')
    result.gsub!('\\\\', '\\')
    return result
end

def escape_xml(string)
    s = string.gsub('&', '&amp;')
    s = s.gsub('<', '&lt;').gsub('>', '&gt;')
    return s
end

def to_uri(uri)
    if uri =~ /^[a-zA-Z]+\:\/\/.+/
        return uri
    else
        return 'http://'+uri
    end
end
class Object
    def deep_clone
        Marshal.load(Marshal.dump(self))
    end
end
