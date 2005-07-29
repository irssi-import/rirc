class Item
    def <=>(object)
        return 0 unless @name
        return 1 unless object
        return @name<=>object.name
    end
    
    #~ def ==(object)
        #~ return nil unless object
        #~ return @name == object.name
    #~ end
end

class Network < Item
    attr_reader :name, :protocol
    attr_accessor :charset
    def initialize(name, protocol)
        @name = name
        @protocol = protocol
        @gateways = ItemList.new(Gateway)
        @presences = ItemList.new(Presence)
    end
    
    def add_gateway(host, port=nil)
        return @gateways.add(host, port)
    end
    
    def gateways
        return @gateways
    end
    
    def add_presence(name)
        return @presences.add(name)
    end
    
    def presences
        return @presences
    end
    
    def presences=(list)
        @presences = list
    end
    
    def gateways=(list)
        @gateways = list
    end
    
    def diff(object)
        settings = []
        if object.charset != @charset
            settings.push('charset='+@charset.to_s)
        end
        
        if settings.empty?
            return nil
        else
            return settings.join(';')
        end
    end
    
    def update(object)
        @charset = object.charset
    end
    
    def create
        string = 'network add;network='+@name+';protocol='+@protocol
        if @charset
            string += ';charset='+@charset
        end
        return string
    end
    
end

class Protocol < Item
    attr_reader :name, :charset
    def initialize(name, charset)
        @name = name
        @charset = charset
    end
end

class Gateway < Item
    attr_reader :network
    attr_accessor :host, :port, :password, :priority
    def initialize(host, port=nil)
        @host = host
        @port = port
    end
    
    def name
        return @host
    end
    
    def diff(object)
        settings = []
        settings.push('port='+@port.to_s) if object.port != @port
        settings.push('password='+@password.to_s) if object.password != @password
        #settings.push('port='+port) if object.port != @port
        
        if settings.empty?
            return nil
        else
            return settings.join(';')
        end
    end
    
    def update(object)
        @port = object.port
        @password = object.password
        @priority = object.priority
    end
    
    def create(network)
        string = 'gateway add;host='+@host+';network='+network
        if @port
            string += ';port='+@port
        end
        if @password
            string += ';password='+@password
        end
        return string
    end
    
    #~ def ==(object)
        #~ return false unless object
        #~ x = (@host == object.host and @port == object.port)
        #~ return x
    #~ end
end

class Presence < Item
    attr_reader :name
    attr_accessor :autoconnect
    def initialize(name)
        @name = name
    end
    
    def diff(object)
        settings = []
        if object.autoconnect != @autoconnect
            if @autoconnect
                settings.push('autoconnect')
            else
                settings.push('autoconnect=')
            end
        end
        
        if settings.empty?
            return nil
        else
            return settings.join(';')
        end
    end
    
    def update(object)
        @autoconnect = object.autoconnect
    end
    
    def create(network)
        string = 'presence add;mypresence='+@name+';network='+network
        return string
    end
end

class ItemList
    attr_reader :list
    def initialize(classtype)
        @classtype = classtype
        @list = []
    end
    
    def [](key)
        results = []
        @list.each do |item|
            if item.name == key
                return item
            end
        end
        
        return nil
        
        #~ if results.length == 1
            #~ return results[0]
        #~ elsif results.length > 1
            #~ return results
        #~ else
            #~ return nil
        #~ end
    end
    
    def []=(key, replacement)
        results = []
        @list.each do |item|
            if item.name == key
                return item.update(replacement)
            end
        end
        
        return nil
    end
    
    #~ def exists?(*args)
        #~ item = @classtype.new(*args)
        #~ return includes?(item)
    #~ end
    
    def add(*args)
        item = @classtype.new(*args)
        return nil if self.include?(item)
        @list.push(item)
        return item
    end
    
    def insert(item)
        return nil if self.include?(item)
        @list.push(item)
        return item
    end
    
    def remove(item)
        @list.delete(item)
    end
    
    def include?(item)
        @list.each do |i|
            if i.name == item.name
                return true
            end
        end
        return false
    end
    
    def sort!
        @list.sort!
        return @list
    end
    
    def sort
        return @list.sort
    end
end