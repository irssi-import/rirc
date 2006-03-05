#TODO Drive a stake through this code's evil heart and replace it with something pure and elegant, preferably without breaking API

#include this in any classes where you want plugins
module PluginAPI
    @@cb_hash = {}
    @@cb_hash_after = {}
    #calls all the callback blocks associated with method, should exit if a block returns true
    def callback(method, *args)

        #lookup the hash
        #         cb_hash = self.class.cb_hashes
        #         cb_hash ||= resolve_cb_hashes

        #return if we get nothing
        #         callbacks = self.class.find_callbacks(method.to_sym)
        #         unless cb_hash
        #             puts cb_hash
        #             puts 'empty callback hash for '+self.class.to_s
        #             return *args 
        #         end

        #check if the callback is in the hash
        #         if cb_hash.has_key?(method.to_sym)
        #initialize the return value as nil
        ret = nil

        #loop through the callbacks
        #             cb_hash[method.to_sym].each do |callback|
        self.class.find_callbacks(method.to_sym).each do |callback|

            #call the block and get the return value
            #what about instance_eval here?
            ret = self.instance_exec(*args, &callback)
            #                 ret = callback.call(self, *args)

            #if return value is true, break off calling any more callbacks (like GTK's system)
            if ret === true
                break
                #if its an array, store the results so they can be passed to sucessive callbacks
            elsif ret.kind_of? Array
                ret.each_with_index { |z, i| args[i]=z}

                #if a single value, assume first argument is returned
            elsif ret
                args[0] = ret
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
        #         cb_hash_after = self.class.cb_hashes_after
        #         cb_hash_after ||= resolve_cb_hashes_after

        #         #return if nothing
        #         unless cb_hash_after
        #             puts 'empty callback_after hash for '+self.class.to_s
        #             return *args 
        #         end

        #check if the callback is in the hash
        #         if cb_hash_after.has_key?(method.to_sym)

        #init the return value to nil
        ret = nil

        #loop through the callbacks
        #             cb_hash_after[method.to_sym].each do |callback|
        self.class.find_callbacks_after(method.to_sym).each do |callback|
            #call the callback, and get the return stuff
            ret = self.instance_exec(*args, &callback)
            #                 ret = callback.call(self, *args)

            #if callback returns true, break off calling any other callbacks like GTK's signals
            if ret === true
                break

                #if its an array, update the original arguments (assume they're passed in order)
            elsif ret.kind_of? Array
                ret.each_with_index { |z, i| args[i]=z}

                #if single return, assume first argument
            elsif ret
                args[0] = ret
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
        return unless file = Plugin.find_plugin(name)
        @config['plugins'] = [] unless @config['plugins'].class == Array
        @config['plugins'].push(name) unless @config['plugins'].include?(name)

        #check if it exists, if so, load it
        if File.exists?(file)
            begin
                load(file, true)
            rescue Exception => details
                puts 'Error loading plugin '+name+' : '+details.message
                puts details.backtrace
                @config['plugins'].delete(name)
                return false
            end

            #no plugin found
        else
            puts 'plugin file '+file+' not found'
            @config['plugins'].delete(name)
            return false
        end
        Plugin[name]
    end

    #wrapper function for class method
#     def resolve_cb_hash
#                 puts 'resolving cb_hash'
#         return self.class.resolve_cb_hash
#     end

#     #wrapper function for class method
#     def resolve_cb_hash_after
#                 puts 'resolving cb_hash_after'
#         return self.class.resolve_cb_hash_after
#     end

    #hyperextend!, these methods are added as class methods
    module Plugins
        #define a callback
        def add_callback(name, &block)
            #initialize the hash if it doesn't exist
            @cb_hash ||= Hash.new

            #make sure there's a function to attach a callback to
            if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)

                #make a new array for the callback if need be, this allows multiple callbacks per function, executed in the order they were added
                @cb_hash[name.to_sym] ||= Array.new
                if block_given?

                    #add the block to the array
                    @cb_hash[name.to_sym].push(block)
                    puts 'added callback for '+name
                    puts @cb_hash.inspect
                    #                     ObjectSpace.each_object(self) do |klass|
                    #puts klass
                    #                         klass.class.resolve_cb_hash
                    #                     end
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
            @cb_hash_after ||= Hash.new

            #check to see if there's a function to attach to
            if self.private_instance_methods.include?(name) or self.instance_methods.include?(name)
                #make an array for the callbacks if there isn't one
                @cb_hash_after[name.to_sym] ||= Array.new
                if block_given?
                    @cb_hash_after[name.to_sym].push(block)
                    puts 'added callback_after for '+name
                    puts @cb_hash_after.inspect
                    #                     ObjectSpace.each_object(self) do |klass|
                    #puts klass.class
                    #                         klass.class.resolve_cb_hash_after
                    #                     end
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
            puts @cb_hash.inspect
#             resolve_cb_hashes
        end

        #remove a callback_after
        def del_callback_after(name)
            @cb_hash_after.delete(name.to_sym)
            puts @cb_hash_after.inspect
#             resolve_cb_hashes_after
            puts @cb_hashes_after.inspect
        end

        #remove a method
        def del_method(name)
            self.send(:remove_method, name.to_sym)
#             puts self.methods.inspect
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
            #puts 'added '+name
            return name
        end

        #reader for cb_hash...?
        def cb_hash
            @cb_hash ||= Hash.new
            return @cb_hash
        end

        def cb_hashes
            resolve_cb_hashes unless @cb_hashes
            @cb_hashes
        end

        #lookup parent classes for callbacks
        #TODO is there a way to do this less then once per callback call without messing up plugin unloading?
        def resolve_cb_hashes
            #a new hash to store the resulting callbacks
            hashes = [cb_hash]

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
                if klass.respond_to? :cb_hash
                    hashes << klass.cb_hash# if klass.cb_hash
                end
            end

            #return
            #return temphash
            @cb_hashes = hashes
        end

        def find_callbacks(method)
            ret = []
            x = cb_hashes.select{|x| x.has_key? method}
#             puts x.inspect, @cb_hashes.inspect
            x.each do |y|
                ret += y[method]
            end
#             puts "found callbacks: #{ret.inspect}"
            ret
        end

        def find_callbacks_after(method)
#             puts method
            ret = []
            x = cb_hashes_after.select{|x| x.has_key? method}
#             puts x.inspect, @cb_hashes_after.inspect
            x.each do |y|
                ret += y[method]
            end
#             puts "found callbacks after: #{ret.inspect}"
            ret
        end

        #reader for cb_hash_after
        def cb_hash_after
            @cb_hash_after ||= Hash.new
            return @cb_hash_after
        end

        def cb_hashes_after
            resolve_cb_hashes_after unless @cb_hashes_after
            @cb_hashes_after
        end

        #lookup parent classes for callback_after
        def resolve_cb_hashes_after

            #new hash to store results
            hashes = [cb_hash_after]

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
                puts klass, klass.respond_to?(:cb_hash_after)
                if klass.respond_to? :cb_hash_after
#                     puts "#{klass} has cb_hash_after"
#                     puts klass.cb_hash_after.inspect
                    hashes <<  klass.cb_hash_after# if klass.cb_hash_after
                end
            end

            #return
            #return temphash
            puts "resolved cb_hashes_after to: #{hashes.inspect} for class #{self}"
            @cb_hashes_after = hashes
        end
    end

    extend Plugins

    def self.append_features(klass)
        super
        klass.extend(Plugins)
    end

    def method_missing(symbol, *args)
        plugin = Plugin.find_plugin_method(symbol)
        if plugin
            plugin[0].send(symbol, *args)
        else
            puts "cannot find method #{symbol} in plugins"
            nil
            #             raise NoMethodError
        end
    end
end

#the plugin class, all plugins are derivatives of this class
class Plugin
    include PluginAPI

    def self.main=(main)
        @@main= main
        #         puts "set main to #{main}"
    end

    #register a plugin
    def self.register(plugin)
        #         puts 'registeting'
        if /([\w\-]+)\.rb/.match(caller[0])
            unless find_plugin($1)
                raise SystemCallError, 'No such file '+$1+' to load as plugin', caller
            end
            name = $1
        else
            raise SystemCallError, 'Plugin does not have a name', caller
        end

        #plugin must be a child of Plugin class..
        unless plugin.class.superclass == Plugin
            puts 'Plugin must be subclass of Plugin'
            return
        end

        #make sure its not already defined
        if self[name]
            puts "a plugin called #{name} is already registered"
            return
        end

        #init the plugin hash if it doesn't exist
        @@plugins ||= {}

        #stuff the data in it
        @@plugins[plugin] = {:name => name, :callbacks => Array.new, :callbacks_after => Array.new, :methods => Array.new} if plugin and !@@plugins[plugin]

        #call the plugins load() method
        @@main.console.send_user_event({'msg' => 'Loading Plugin '+name}, EVENT_NOTICE)
        plugin.load
        #         puts self, self.class
    end

    def help(a, b)
        self.class.help(a, b)
    end

    #TODO - what if the function we lookup is shared between multiple plugins?
    def self.find_plugin_method(method)
        plugin = @@plugins.detect do |p, info|
            p.respond_to? method
        end
        plugin
    end

    #unload a plugin and remove all methods/callbacks added by it...
    def self.unregister(plugin)

        #make sure the plugin is registered
        return false unless @@plugins and @@plugins[plugin]

        #remove all the callbacks
        @@plugins[plugin][:callbacks].each do |c|
            c[:class].del_callback(c[:callback])
            puts 'removed callback '+c[:callback]+' for class '+c[:class].to_s
        end

        #remove all the callback_afters
        @@plugins[plugin][:callbacks_after].each do |c|
            c[:class].del_callback_after(c[:callback])
            puts 'removed callback_after '+c[:callback]+' for class '+c[:class].to_s
        end

        #remove all the methods
        @@plugins[plugin][:methods].each do |c|
            c[:class].del_method(c[:method])
            puts 'removed method '+c[:method]+' for class '+c[:class].to_s
        end

        @@main.config['plugins'].delete(@@plugins[plugin][:name])

        #delete the plugin from the hash
        @@plugins.delete(plugin)

        #call the unload function if the plugin wants to do any additional cleanup
        plugin.unload
        true
    end

    #list registered plugins.
    def self.list
        @@plugins ||= {}
        return @@plugins
    end

    #lookup a string as a plugin name
    def self.[](name)
        #         puts "looking up #{name}"
        @@plugins ||= {}
        x = @@plugins.detect{|p| p[1][:name] == name}
        x = x[0] if x
        return x
    end

    #wrapper function for adding a callback to a class
    def add_callback(plugin, classname, name, &block)

        #make sure the plugin is registered
        if @@plugins[plugin]
            #add the callback, make sure its not already defined for this plugin and then define it iof add is sucessful
            if callback = classname.add_callback(name, &block) and  !@@plugins[plugin][:callbacks].include?({:callback=>callback, :class=>classname})
                @@plugins[plugin][:callbacks].push({:callback=>callback, :class=>classname})
            end

            #error
        else
            puts 'plugin not registered'
        end
    end

    def add_callback_after(plugin, classname, name, &block)

        #make sure the plugin is registered
        if @@plugins[plugin]
            #add the callback, make sure its not already defined for this plugin and then define it if add is sucessful
            if callback = classname.add_callback_after(name, &block) and  !@@plugins[plugin][:callbacks_after].include?({:callback=>callback, :class=>classname})
                @@plugins[plugin][:callbacks_after].push({:callback=>callback, :class=>classname})
            end

            #error
        else
            puts 'plugin not registered'
        end
    end

    def add_method(plugin, classname, name, &block)
        #make sure the plugin is registered
        if @@plugins[plugin]
            #add the callback, make sure its not already defined for this plugin and then define it if add is sucessful
            if method = classname.add_method(name, &block) and  !@@plugins[plugin][:methods].include?({:method=>method, :class=>classname})
                @@plugins[plugin][:methods].push({:method=>method, :class=>classname}) 
            end

            #error
        else
            puts 'plugin not registered'
        end
    end

    def self.find_plugin(name)
        return unless name
        name += '.rb'
        dir1 = File.join($ratchetfolder, 'plugins')
        dir2 = 'plugins'
        if File.directory?(dir1) and Dir.entries(dir1).include?(name)
            return File.join(dir1, name)
        elsif File.directory?(dir2) and Dir.entries(dir2).include?(name)
            return File.join(dir2, name)
        else
            return false
        end
    end

    #stub for unload function to allow plugins to do additional cleanup
    def unload
    end

    #stub for configure function
    def configure
        []
    end
end

class PluginConfig
    def initialize(main, options)
        @main = main
        @config = @main.config
        return if options.length == 0 
        @glade = GladeXML.new("gtk/glade/pluginconf.glade") {|handler| method(handler)}

        @tooltips = Gtk::Tooltips.new

        @table = @glade['optiontable']
        @table.resize(options.length, 2)
        @table.border_width = 10
        @table.column_spacings = 10
        @table.row_spacings = 5
        @configarray = {}

        handle_options(options)
        @window = @glade['confwindow']
        @window.show_all
    end

    def handle_options(options)
        i = 0
        options.each do |option|
            if option['type'] and option['name'] and option['description']
                #fill in defaults for unset values
                option['tooltip'] ||= nil
                option['value'] ||= nil
                option['xopt'] ||= Gtk::SHRINK
                option['yopt'] ||= Gtk::FILL

                if option['type'] == Color
                    widget = Gtk::ColorButton.new
                    widget.color = Gdk::Color.new(*option['value']) if option['value']
                    widget.signal_connect('color_set') {|widget| color_changed(widget)}
                elsif option['type'] == String
                    #I guess we need some trick to allow combo boxes too...
                    widget = Gtk::Entry.new
                    widget.text = option['value'] if option['value']
                    widget.signal_connect('changed') {|widget| text_changed(widget)}
                elsif option['type'] == Integer
                    widget = Gtk::Entry.new
                    widget.text = option['value'].to_s if option['value']
                    widget.signal_connect('changed') {|widget| integer_changed(widget)}
                elsif option['type'] == TrueClass
                    widget = Gtk::CheckButton.new#(option['description'])
                    widget.active = false
                    widget.active = true if option['value'] == true
                    widget.signal_connect('toggled') {|widget| bool_changed(widget)}
                elsif option['type'] == Array
                    widget = Gtk::Entry.new
                    widget.text = option['value'].join(',') if option['value']
                    widget.signal_connect('changed') {|widget| array_changed(widget)}
                else
                    puts 'unknown type '+option['type'].to_s
                    next
                end
                @tooltips.set_tip(widget, option['tooltip'], '') if option['tooltip']
                @configarray[widget] = {'name' => option['name'], 'value' => option['value']}
                @table.attach(Gtk::Label.new(option['description']), 0, 1, i, i+1, Gtk::SHRINK, Gtk::FILL)# unless option['type'] == TrueClass
                @table.attach(widget, 1, 2, i, i+1, Gtk::SHRINK, Gtk::FILL)
                i += 1
            else
                puts 'missing required options'
            end
        end
    end

    def bool_changed(widget)
        change_setting(widget, widget.active?)
    end

    def color_changed(widget)
        change_setting(widget, Color.new(*widget.color.to_a))
    end

    def text_changed(widget)
        change_setting(widget, widget.text)
    end

    def integer_changed(widget)
        change_setting(widget, widget.text.to_i)
    end

    def array_changed(widget)
        change_setting(widget, widget.text.split(',').uniq)
    end

    def change_setting(widget, setting)
        #puts 'changed setting of '+widget.name+' to '+setting.to_s
        @configarray[widget]['value'] = setting
    end

    def update_config
        @configarray.each do |k, v|
            #puts v['name']+' = '+v['value'].to_s
            @config[v['name']] = v['value']
        end
        destroy
        @main.send_command('sendconfig', @config.changes)
    end

    def destroy
        @window.destroy
    end
end
