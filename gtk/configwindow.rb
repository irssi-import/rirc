
class ConfigWindow
    def initialize(main)
        @main = main
        @config = @main.config
        @glade = GladeXML.new("gtk/glade/config.glade") {|handler| method(handler)}
        @window = @glade['config']
        @preferencesbar = @glade['preferencesbar']
        @configarea = @glade['configarea']
        @treestore = Gtk::TreeStore.new(String)
        @preferencesbar.model = @treestore
        @treeselection = @preferencesbar.selection
        @treeselection.signal_connect('changed') do |widget|
            switch_category(widget.selected)
        end
        
        @channellistposition = @glade['tablistposition']
        @options = {}
        @options['tablistposition'] = ['Top', 'Bottom', 'Left', 'Right', 'UnderUserList']
        @options['canonicaltime'] = ['Server', 'Client']
        @options['tabcompletesort'] = ['Alphabetical', 'Activity']
        @options['tablisttype'] = ['Button', 'TreeView']
        @options['tabstructure'] = ['Hierarchical', 'Flat']
        @options['tabsort'] = ['Case Insensitive', 'Case Sensitive', 'Case Insensitive No Hash', 'Case Sensitive No Hash']
		
        parent = @treestore.append(nil)
        parent[0] = "Interface"
        child2 = @treestore.append(parent)
        child2[0] = "Miscallenous"
        child = @treestore.append(parent)
        child[0] = "Templates"
        child = @treestore.append(parent)
        child[0] = "Colors"
		
        @glade['temp2'].remove(@glade['miscconfig'])
        @glade['temp1'].remove(@glade['colorconfig'])
        
        @glade['temp1'].destroy
        @glade['temp2'].destroy
        
        @categories = {'Miscallenous' => @glade['miscconfig'], 'Templates'=>@glade['promptconfig'], 'Colors' => @glade['colorconfig']}
        renderer = Gtk::CellRendererText.new
        
        col = Gtk::TreeViewColumn.new("", renderer, :text => 0)
        @preferencesbar.append_column(col)
        @preferencesbar.expand_all
        @treeselection.select_iter(child2)
        @currentcategory = @configarea.child
        draw_category(@categories['Miscallenous'])
        @configarray = {}
        @configbackup = {}

        fill_values
    end
	
    def fill_values(values = @config.values)
        #values = $config.get_all_values
		
        values.each do | key, value|
            if @glade[key]
                if @glade[key].class == Gtk::Entry
                    @glade[key].text = value
                    @glade[key].signal_connect('changed') do |widget|
                        change_setting(widget, widget.text)
                    end
                    @configarray[@glade[key]] = {'name' => key, 'value' => value}
                    @configbackup[key] ||= value
                elsif @glade[key].class == Gtk::ComboBox
                    i = 0
                    match = false
                    #fill the combobox
                    @configarray[@glade[key]] = {'name' => key, 'value' => value}
                    @configbackup[key] ||= value
#                     puts key, @options[key]
                    next unless @options[key]
                    @options[key].each do |v|
                        @glade[key].append_text(v)
                        if value == v.downcase
                            @glade[key].active = i
                            match = true
                        end
                        i += 1
                    end
            
                    unless match
                        @glade[key].active == 0
                    end
                    #	@glade[key].active = 1
                    #end
                elsif @glade[key].class == Gtk::ColorButton and value.class == Color
                    #color_button(@glade[key], Gdk::Color.new(*value))
                    @configarray[@glade[key]] = {'name' => key, 'value' => value}
                    @configbackup[key] ||= value
                    @glade[key].color = Gdk::Color.new(*value)
                elsif @glade[key].class == Gtk::CheckButton
                    @configarray[@glade[key]] = {'name' => key, 'value' => value}
                    @configbackup[key] ||= value
                    if value
                        @glade[key].active = true
                    else
                        @glade[key].active = false
                    end
                elsif @glade[key].class == Gtk::FontButton
                    @configarray[@glade[key]] = {'name' => key, 'value' => value}
                    @configbackup[key] ||= value
                    @glade[key].font_name = value
                end
            end
        end
        #@glade['message'].text = @config['message']
    end
	
    def color_button(button, color)
        button.modify_bg(Gtk::STATE_NORMAL, color)
    end
    
    def switch_category(selection)
        draw_category(@categories[selection[0]]) if selection and @categories[selection[0]]
    end
    
    def draw_category(category)
        @configarea.remove(@currentcategory)
        @configarea.add(category)
        @currentcategory = category
    end

    def change_setting(widget, setting)
        puts 'changed setting of '+widget.name+' to '+setting.to_s
        @configarray[widget] = {'name' => widget.name, 'value' => setting}# unless @configbackup[widget.name] == setting
    end

    def color_changed(widget)
        change_setting(widget, Color.new(*widget.color.to_a))
    end
    
#     def change_color(widget, color)
#         color_button(widget, color)
#         change_setting(widget, Color.new(*color.to_a))
#         #$config.set_value(widget.name, color)
#     end
#     
#     def select_color(widget)
#         button = widget
#         @configarray[widget] = {'name' => widget.name} unless @configarray[widget]
#         color = nil
#         color = Gdk::Color.new(*@configarray[widget]['value']) if @configarray[widget]['value']
#         selectordialog = Gtk::ColorSelectionDialog.new
#         selectordialog.modal = true
#         selector = selectordialog.colorsel
#         if color
#             selector.current_color = color
#             selector.previous_color = color
#         end
#         selectordialog.run do |response|
#             case response
#                 when Gtk::Dialog::RESPONSE_OK
#                     change_color(button, selector.current_color)
#                 #else
#                     #do_nothing_since_dialog_was_cancelled()
#             end
#             selectordialog.destroy
#         end
#     end
    
    def combobox_changed(widget)
        change_setting(widget, @options[widget.name][widget.active].downcase)
    end
    
    def tickbox_changed(widget)
        change_setting(widget, widget.active?)
    end
	
    def font_changed(widget)
        #puts 'changed font'+widget.font_name
        change_setting(widget, widget.font_name)
    end
    
    def revert_config
        #$config.revert_to_defaults
        fill_values(@config.defaults)
    end
    
    def update_config
        #$config.create_config_snapshot
        @config.update_snapshot(@configbackup)
        #pass all the values back to $config
        @configarray.each do |k, v|
            @config[v['name']] = v['value']
        end
        destroy
        @main.windows.each{|window| window.draw_from_config}
        @main.buffers.values.select{|x| x.buffer}.each{|x| x.buffer.redraw}
        changes = @config.changes
        @main.send_command('sendconfig', changes) if changes
        @main.restyle
    end
	
    def show_all
        @window.show_all
    end
    
    def destroy
        @window.destroy
    end
end
