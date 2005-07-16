#extend this on any classes you want plugins
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
                return name
            end
        else
            puts 'no event function called '+name+', not adding callback'
            return nil
        end
    end
    
    def del_callback(name)
        @cb_hash.delete(name.to_sym)
    end
    
    def del_method(name)
        self.send(:remove_method, name.to_sym)
    end
    
    #add a new input handler
    def add_method(name, &block)
        if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
            puts 'method '+name+' already defined, not redefining'
            return nil
        end
        #puts self, self.class
        self.send(:define_method, name, &block)
        puts 'added '+name
        return name
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

#include this in any classes where you want plugins
module PluginAPI
    #calls all the blocks associated with method, should exit if a block returns true
    def callback(method, *args)
        cb_hash = resolve_cb_hash
        unless cb_hash
            puts 'empty hash for '+self.class.to_s
            return *args 
        end
        #cb_hash.each{|k, v| puts k}
        if cb_hash.has_key?(method.to_sym)
            #puts 'callbacks for '+method
            ret = nil
            cb_hash[method.to_sym].each do |hash|
                puts 'a callback'
                ret = hash.call(*args)
                if ret === true
                    break
                elsif ret.class == Array
                    ret.each_with_index { |z, i| args[i]=z}
                elsif ret
                    args[0] = ret
                end
            end
        end
        if ret === true
            puts 'returned true, disabling further callbacks or functions for '+method
            return true
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

#the plugin class, all plugins are derivatives of this class
class Plugin
    include Plugins
    attr_reader :name
    def initialize(name)
        @name = name
    end
    
    def self.register(plugin)
        unless plugin.name
            puts 'plugin must have a name'
            return
        end
        unless plugin.class.superclass == Plugin
            puts 'Plugin must be subclass of Plugin'
            return
        end
        if lookup(plugin.name)
            puts 'a plugin with this name is already registered'
            return
        end
        
        @@plugins ||= {}
        @@plugins[plugin] = {'callbacks' => Array.new, 'methods' => Array.new} if plugin and !@@plugins[plugin]
        plugin.load
    end
    
    def self.unregister(plugin)
        return unless @@plugins and @@plugins[plugin]
        
        @@plugins[plugin]['callbacks'].each do |c|
            c[1].del_callback(c[0])
            puts 'removed callback '+c[0]+' for class '+c[1].to_s
        end
        
        @@plugins[plugin]['methods'].each do |c|
            c[1].del_method(c[0])
            puts 'removed method '+c[0]+' for class '+c[1].to_s
        end
        @@plugins.delete(plugin)
        plugin.unload
    end
    
    def self.list
        @@plugins ||= {}
        return @@plugins
    end
    
    def self.lookup(name)
        @@plugins ||= {}
        @@plugins.each do |plugin, values|
            if plugin.name == name
                return plugin
            end
        end
        return nil
    end
    
    def add_callback(plugin, classname, name, &block)
        if @@plugins[plugin]
            if callback = classname.add_callback(name, &block) and  !@@plugins[plugin]['callbacks'].include?([callback, classname])
                @@plugins[plugin]['callbacks'].push([callback, classname])
            end
        else
            puts 'plugin '+plugin.name+' not registered'
        end
    end
    
    def add_method(plugin, classname, name, &block)
        if @@plugins[plugin]
            if method = classname.add_method(name, &block) and  !@@plugins[plugin]['methods'].include?([method, classname])
                @@plugins[plugin]['methods'].push([method, classname]) 
            end
        else
            puts 'plugin '+plugin.name+' not registered'
        end
    end
    
    def unload
    end
end