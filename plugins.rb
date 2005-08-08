#TODO Drive a stake through this code's evil heart and replace it with something pure and elegant, preferably without breaking API

#extend this on any classes you want plugins
module Plugins

    #define a callback
    def add_callback(name, &block)
    
        #initialize the hash if it doesn't exist
        @cb_hash ||= Hash.new(nil)
        
        #make sure there's a function to attach a callback to
        if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
        
            #make a new array for the callback if need be, this allows multiple callbacks per function, executed in the order they were added
            @cb_hash[name.to_sym] ||= Array.new
            if block_given?
            
                #add the block to the array
                @cb_hash[name.to_sym].push(block)
                puts 'added callback for '+name
                
                #return the name of the callback..?
                return name
            end
        else
            #no function to attach to...
            puts 'no event function called '+name+', not adding callback'
            return nil
        end
    end
    
    #add a callback to be executed after a function
    def add_callback_after(name, &block)
        #again, make the hash if it doesn't exist
        @cb_hash_after ||= Hash.new(nil)
        
        #check to see if there's a function to attach to
        if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
            #make an array for the callbacks if there isn't one
            @cb_hash_after[name.to_sym] ||= Array.new
            if block_given?
                @cb_hash_after[name.to_sym].push(block)
                puts 'added callback_after for '+name
                
                #return the name, not sure why...
                return name
            end
        else
            #no function!
            puts 'no event function called '+name+', not adding callback'
            return nil
        end
    end
    
    #remove a callback
    def del_callback(name)
        #puts self.class
        puts @cb_hash.delete(name.to_sym)
    end

    #remove a callback_after
    def del_callback_after(name)
        @cb_hash_after.delete(name.to_sym)
    end

    #remove a method
    def del_method(name)
        self.send(:remove_method, name.to_sym)
    end
    
    #add a new method
    def add_method(name, &block)
        #make sure its not already defined....
        if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
            puts 'method '+name+' already defined, not redefining'
            return nil
        end
        
        #call define method and add it.
        self.send(:define_method, name, &block)
        puts 'added '+name
        return name
    end
    
    #reader for cb_hash...?
    def cb_hash
        return @cb_hash
    end
    
    #lookup parent classes for callbacks
    #TODO is there a way to do this less then once per callback call without messing up plugin unloading?
    def resolve_cb_hash
        #a new hash to store the resulting callbacks
        temphash = Hash.new
        
        #loop through the parent classes, and build an array of them....
        c = self
        classes = Array.new
        
        while c != Object || nil
            classes.push(c)
            c = c.superclass
        end
        
        #reverse the array of classes, so callbacks are overridden in child classes
        classes.reverse!
        
        #loop through, and add callbacks
        classes.each do |klass|
            if klass.methods.include?('cb_hash')
                temphash.merge!(klass.cb_hash) if klass.cb_hash
            end
        end

        #return
        return temphash
    end
    
    #reader for cb_hash_after
    def cb_hash_after
        return @cb_hash_after
    end
    
    #lookup parent classes for callback_after
    def resolve_cb_hash_after
    
        #new hash to store results
        temphash = Hash.new
        
        #loop through parents and build an array
        c = self
        classes = Array.new
        
        while c != Object || nil
            classes.push(c)
            c = c.superclass
        end
        
        #invert the array, so child callbacks override parents
        classes.reverse!
        
        #build hash of callback_after
        classes.each do |klass|
            if klass.methods.include?('cb_hash_after')
                temphash.merge!(klass.cb_hash_after) if klass.cb_hash_after
            end
        end
        
        #return
        return temphash
    end
end

#include this in any classes where you want plugins
module PluginAPI

    #calls all the callback blocks associated with method, should exit if a block returns true
    def callback(method, *args)
    
        #lookup the hash
        cb_hash = resolve_cb_hash
        
        #return if we get nothing
        unless cb_hash
            puts 'empty hash for '+self.class.to_s
            return *args 
        end
        
        #check if the callback is in the hash
        if cb_hash.has_key?(method.to_sym)
            #initialize the return value as nil
            ret = nil
            
            #loop through the callbacks
            cb_hash[method.to_sym].each do |hash|
            
                #call the block and get the return value
                ret = hash.call(self, *args)
                
                #if return value is true, break off calling any more callbacks (like GTK's system)
                if ret === true
                    break
                #if its an array, store the results so they can be passed to sucessive callbacks
                elsif ret.class == Array
                    ret.each_with_index { |z, i| args[i]=z}
                
                #if a single value, assume first argument is returned
                elsif ret
                    args[0] = ret
                end
            end
        end
        
        #if it returned true, let the calling function know
        if ret === true
            puts 'returned true, disabling further callbacks or functions for '+method
            return true
        end
        
        #otherwise return the arguments, possibly modified by callbacks.
        return args
    end
    
    #calls all the callback_after blocks associated with method, should exit if a block returns true
    def callback_after(method, *args)
        #lookup the hash
        cb_hash_after = resolve_cb_hash_after
        
        #return if nothing
        unless cb_hash_after
            puts 'empty hash for '+self.class.to_s
            return *args 
        end
        
        #check if the callback is in the hash
        if cb_hash_after.has_key?(method.to_sym)
        
            #init the return value to nil
            ret = nil
            
            #loop through the callbacks
            cb_hash_after[method.to_sym].each do |hash|
                #call the callback, and get the return stuff
                ret = hash.call(self, *args)
                
                #if callback returns true, break off calling any other callbacks like GTK's signals
                if ret === true
                    break
                
                #if its an array, update the original arguments (assume they're passed in order)
                elsif ret.class == Array
                    ret.each_with_index { |z, i| args[i]=z}
                
                #if single return, assume first argument
                elsif ret
                    args[0] = ret
                end
            end
        end
        
        #let the calling function know it returned true
        if ret === true
            puts 'returned true, disabling further callbacks or functions for '+method
            return true
        end
        
        #otherwise, return the arguments, possibly modified by callbacks
        return args
    end
    
    #resolves the method name of the current method (is this still needed?)
    def get_method_name()
	  /\`([^\']+)\'/.match(caller(1).first)[1].to_sym # we need a ' to close the damn thing :)
	end
    
    #load a plugin
    def plugin_load(name)
        #expand the name
        file = 'plugins/'+name+'.rb'
        
        #check if it exists, if so, load it
        #TODO - maybe have ~/.rirc/plugins as a per-user plugin location....
        if File.exists?(file)
            begin
                load(file, true)
            rescue Exception
                puts 'Error loading plugin '+name+' : '+$!
            end
            
        #no plugin found
        else
            puts 'plugin file '+file+' not found'
        end
    end
    
    #wrapper function for class method
    def resolve_cb_hash
        return self.class.resolve_cb_hash
    end
    
    #wrapper function for class method
    def resolve_cb_hash_after
        return self.class.resolve_cb_hash_after
    end
    
end

#the plugin class, all plugins are derivatives of this class
class Plugin
    include Plugins
    attr_reader :name
    
    def initialize(name)
        @name = name
    end
    
    #register a plugin
    def self.register(plugin)
        #make sure its named
        unless plugin.name
            puts 'plugin must have a name'
            return
        end
        
        #plugin must be a child of Plugin class..
        unless plugin.class.superclass == Plugin
            puts 'Plugin must be subclass of Plugin'
            return
        end
        
        #make sure its not already defined
        if lookup(plugin.name)
            puts 'a plugin with this name is already registered'
            return
        end
        
        #init the plugin hash if it doesn't exist
        @@plugins ||= {}
        
        #stuff the data in it
        @@plugins[plugin] = {'callbacks' => Array.new, 'callbacks_after' => Array.new, 'methods' => Array.new} if plugin and !@@plugins[plugin]
        
        #call the plugins load() method
        plugin.load
    end
    
    #unload a plugin and remove all methods/callbacks added by it...
    def self.unregister(plugin)
    
        #make sure the plugin is registered
        return unless @@plugins and @@plugins[plugin]
        
        #remove all the callbacks
        @@plugins[plugin]['callbacks'].each do |c|
            c[1].del_callback(c[0])
            puts 'removed callback '+c[0]+' for class '+c[1].to_s
        end
        
        #remove all the callback_afters
        @@plugins[plugin]['callbacks_after'].each do |c|
            c[1].del_callback_after(c[0])
            puts 'removed callback_after '+c[0]+' for class '+c[1].to_s
        end
        
        #remove all the methods
        @@plugins[plugin]['methods'].each do |c|
            c[1].del_method(c[0])
            puts 'removed method '+c[0]+' for class '+c[1].to_s
        end
        
        #delete the plugin from the hash
        @@plugins.delete(plugin)
        
        #call the unload function if the plugin wants to do any additional cleanup
        plugin.unload
    end
    
    #list registered plugins.
    def self.list
        @@plugins ||= {}
        return @@plugins
    end
    
    #lookup a string as a plugin name
    def self.lookup(name)
        @@plugins ||= {}
        @@plugins.each do |plugin, values|
            if plugin.name == name
                return plugin
            end
        end
        return nil
    end
    
    #wrapper function for adding a callback to a class
    def add_callback(plugin, classname, name, &block)
        
        #make sure the plugin is registered
        if @@plugins[plugin]
            #add the callback, make sure its not already defined for this plugin and then define it iof add is sucessful
            if callback = classname.add_callback(name, &block) and  !@@plugins[plugin]['callbacks'].include?([callback, classname])
                @@plugins[plugin]['callbacks'].push([callback, classname])
            end
            
        #error
        else
            puts 'plugin '+plugin.name+' not registered'
        end
    end
    
    def add_callback_after(plugin, classname, name, &block)
    
        #make sure the plugin is registered
        if @@plugins[plugin]
            #add the callback, make sure its not already defined for this plugin and then define it if add is sucessful
            if callback = classname.add_callback_after(name, &block) and  !@@plugins[plugin]['callbacks_after'].include?([callback, classname])
                @@plugins[plugin]['callbacks_after'].push([callback, classname])
            end
            
        #error
        else
            puts 'plugin '+plugin.name+' not registered'
        end
    end
    
    def add_method(plugin, classname, name, &block)
        #make sure the plugin is registered
        if @@plugins[plugin]
            #add the callback, make sure its not already defined for this plugin and then define it if add is sucessful
            if method = classname.add_method(name, &block) and  !@@plugins[plugin]['methods'].include?([method, classname])
                @@plugins[plugin]['methods'].push([method, classname]) 
            end
        
        #error
        else
            puts 'plugin '+plugin.name+' not registered'
        end
    end
    
    #stub for unload function to allow plugins to do additional cleanup
    def unload
    end
end