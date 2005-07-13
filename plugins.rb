module Plugins
    #attr_accessor :cb_hash
    #define input callbacks
    def add_callback(name, &block)
        @cb_hash ||= Hash.new(nil)
        #puts self
        if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
            @cb_hash[name.to_sym] ||= Array.new
            if block_given?
                @cb_hash[name.to_sym].push(block)
                puts 'added callback for '+name
                #puts @cb_hash[name.to_sym].length
                resolve_cb_hash
            end
        else
            puts 'no event function called '+name+', not adding callback'
        end
    end
    
    #add a new input handler
    def add_method(name, &block)
        if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
            puts 'method '+name+' already defined, not redefining'
            return
        end
        #puts self, self.class
        self.send(:define_method, name, &block)
        puts 'added '+name
    end
    
    def cb_hash
        return @cb_hash
    end
    
    def resolve_cb_hash
        temphash = Hash.new
        
        c = self
        classes = Array.new
        
        while c != Object || nil
            classes.push(c)
            c = c.superclass
        end
        
        classes.reverse!
        
        #classes.each {|k| puts k}
        
        classes.each do |klass|
            if klass.methods.include?('cb_hash')
                temphash.merge!(klass.cb_hash) if klass.cb_hash
            end
        end
        
        @cb_hash = temphash
        
        return @cb_hash
    end
end

module PluginAPI
    #calls all the blocks associated with method, should exit if a block returns true
    def callback(method, *args)
        cb_hash = resolve_cb_hash
        unless cb_hash
            puts 'empty hash for '+self.class.to_s
            return *args 
        end
        cb_hash.each{|k, v| puts k}
        if cb_hash.has_key?(method.to_sym)
            #puts 'callbacks for '+method
            ret = nil
            cb_hash[method.to_sym].each do |hash|
                puts 'a callback'
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
    
    def plugin_load(name)
        file = 'plugins/'+name+'.rb'
        if File.exists?(file)
            load(file, true)
        else
            puts 'plugin file '+file+' not found'
        end
    end
    
    #~ def cb_hash
        #~ return resolve_cb_hash
    #~ end
    
    def resolve_cb_hash
        #puts self, self.class, self.class.cb_hash.length
        return self.class.resolve_cb_hash
    end
    
end

class Plugin
    include Plugins
    
    def add_callback(classname, name, &block)
        classname.add_callback(name, &block)
    end
    
    def add_method(classname, name, &block)
        classname.add_method(name, &block)
    end
    
end