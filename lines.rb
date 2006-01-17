#derive from Hash and simply convert all keys to symbols for internal storage
#also convert all lookup keys to symbols
class Line < Hash
    #convert keys to symbols
    def self.[](*args)
        
        if args[0].class == Hash
            new = {}
            args[0].each do |k,v|
                new[k.to_sym] = v
            end

            args[0] = new
        else
            x = true
            args.each_with_index do |k, i|
                if x 
                   args[i] = k.to_sym
                end
                x = !x
            end
        end
        
        super(*args)
    end

    def[]=(key, value)
        key = key.to_sym
        super(key, value)
    end
    
    def [](key)
        key = key.to_sym
        super(key)
    end
end
