module Plugins
    #calls all the blocks associated with method, should exit if a block returns true
    def callback(method, *args)
        args.class
        if @cb_hash[method]
            ret = nil
            @cb_hash[method].each do |hash|
                ret = hash.call(*args)
                if ret == true
                    break
                elsif ret.class == Array
                    ret.each_with_index { |z, i| args[i]=z}
                elsif ret
                    args[0] = ret
                end
            end
        end
        return args
    end
    
    #resolves the method name of the current method
    def get_method_name()
	  /\`([^\']+)\'/.match(caller(1).first)[1].to_sym
	end
    
    #define input callbacks
    def add_callback(name, &block)
        @cb_hash = Hash.new(nil) unless @cb_hash
        if self.respond_to?(name)
            if !@cb_hash[name.to_sym]
                @cb_hash[name.to_sym] = Array.new
            end
            @cb_hash[name.to_sym].push(block) if block_given?
        else
            puts 'no event function called '+name+', not adding callback'
        end
    end
    
    #add a new input handler
    def add_method(name, &block)
        if self.respond_to?(name)
            puts 'method '+name+' already defined, not redefining'
            return
        end
        self.class.send(:define_method, name, &block)
        puts 'added '+name
    end
    
    def plugin_load(name)
        file = 'plugins/'+name+'.rb'
        if File.exists?(file)
            load(file, true)
        else
            puts 'plugin file '+file+' not found'
        end
    end
    
end