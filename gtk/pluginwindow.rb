class PluginWindow < SingleWindow
    def initialize
        @glade = GladeXML.new("glade/plugins.glade") {|handler| method(handler)}
        @window = @glade['pluginwindow']
        @pluginstore = Gtk::ListStore.new(String, Integer)
        @pluginlist = @glade['pluginlist']
        @pluginlist.model = @pluginstore
        
        renderer = Gtk::CellRendererText.new

        col = Gtk::TreeViewColumn.new("Plugin", renderer, :text => 0)
        
        col.set_cell_data_func(renderer) do |col, renderer, model, iter|
            if iter[1] == 0
                renderer.background = "#FFC8CA"
            else
                renderer.background = "#C8FFCC"
            end
        end
        
        @pluginlist.append_column(col)
        
        
        #puts Dir.entries('plugins')
        
        plugins = []
        
        if File.directory?('plugins')
            plugins += Dir.entries('plugins')
        end
        
        if File.directory?(File.join($rircfolder, 'plugins'))
            plugins += Dir.entries(File.join($rircfolder, 'plugins'))
        end
        
        plugins = plugins.uniq.select do |i|
            name, ext = i.split('.')
            if ext
                ext.downcase == 'rb'
            else
                false
            end
        end
        
        plugins.each do |plugin|
            name, extension = plugin.split('.')
            iter = @pluginstore.append
            iter[0] = name
            if $config['plugins'].include?(name)
                puts name
                iter[1] = 1
            else
                iter[1] = 0
            end
            #puts iter[0], iter[1]
        end
        
        @pluginlist.selection.signal_connect('changed') {|widget| update_buttons(widget)}
        
        @open = true
    end
    
    def update_buttons(widget)
        selection = widget.selected
        if selection
            if selection[1] == 1
                @glade['plugin_unload'].sensitive = true
                @glade['plugin_load'].sensitive = false
                @glade['plugin_options'].sensitive = true
            else
                @glade['plugin_load'].sensitive = true
                @glade['plugin_unload'].sensitive = false
                @glade['plugin_options'].sensitive = false
            end
        end
    end
    
    def get_selection
        selection = @pluginlist.selection.selected
        if selection
            return selection
        else
            return nil
        end
    end
    
    def load_plugin
        if selection = get_selection and selection[1] == 0
            if $main.plugin_load(selection[0]) 
                selection[1] = 1
            end
        end
        update_buttons(@pluginlist.selection)
    end
    
    def unload_plugin
        if selection = get_selection and selection[1] == 1
            if plugin = Plugin[selection[0]]
                if Plugin.unregister(plugin)
                    selection[1] = 0
                end
            end
        end
        update_buttons(@pluginlist.selection)
    end
    
    def config_plugin
        if selection = get_selection and selection[1] == 1
            if plugin = Plugin[selection[0]]
                PluginConfig.new(plugin.configure)
            end
        end
    end
    
    def destroy
        @open = false
        @glade['pluginwindow'].destroy
    end
end