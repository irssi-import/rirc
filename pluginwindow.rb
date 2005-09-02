class PluginWindow
    def initialize
        @glade = GladeXML.new("glade/plugins.glade") {|handler| method(handler)}
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
        
        plugins = Dir.entries('plugins').select do |i|
            name, ext = i.split('.')
            if ext
                ext.downcase == 'rb'
            else
                false
            end
        end
        
        puts plugins
        
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
        
        @pluginlist.selection.signal_connect('changed') do |widget|
            selection = widget.selected
            if selection
                if selection[1] == 1
                    @glade['plugin_unload'].sensitive = true
                    @glade['plugin_load'].sensitive = false
                else
                    @glade['plugin_load'].sensitive = true
                    @glade['plugin_unload'].sensitive = false
                end
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
            $main.plugin_load(selection[0]) 
            selection[1] = 1
        end
    end
    
    def unload_plugin
        if selection = get_selection and selection[1] == 1
            if plugin = Plugin.lookup(selection[0])
                Plugin.unregister(plugin)
                selection[1] = 0
            end
        end
    end
    
    def config_plugin
    end
    
    def destroy
        @glade['pluginwindow'].destroy
    end
end