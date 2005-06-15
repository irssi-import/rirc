
class ConfigWindow
	def initialize
		@glade = GladeXML.new("glade/config.glade") {|handler| method(handler)}
		@window = @glade['config']
		@preferencesbar = @glade['preferencesbar']
		@configarea = @glade['configarea']
		@treestore = Gtk::TreeStore.new(String)
		@preferencesbar.model = @treestore
		@treeselection = @preferencesbar.selection
		@treeselection.signal_connect('changed') do |widget|
			switch_category(widget.selected)
		end
		
		@channellistposition = @glade['channellistposition']
		@options = {}
		@options['channellistposition'] = ['Top', 'Bottom', 'Left', 'Right']
		#~ i = 0
		#~ #fill the combobox
		#~ @positions.each do |value|
			#~ @channellistposition.append_text(value)
			#~ if $config['channellistposition'] == value.downcase
				#~ @channellistposition.active = i
			#~ end
			#~ i += 1
		#~ end
		
		parent = @treestore.append(nil)
		parent[0] = "Interface"
		child2 = @treestore.append(parent)
		child2[0] = "Layout"
		child = @treestore.append(parent)
		child[0] = "Prompts"
		child = @treestore.append(parent)
		child[0] = "Colors"
		
		@categories = {'Layout' => @glade['layoutconfig'], 'Prompts'=>@glade['promptconfig'], 'Colors' => @glade['colorconfig']}
		
		#~ @treeselection.set_select_function do
		#~ |selection, model, path, path_currently_selected|
			#~ if selection.selected and !path_currently_selected
				#~ if @categories[selection.selected[0]]
					#~ puts selection.selected[0]
					#~ true
				#~ else
					#~ false
				#~ end
				#~ #puts selection.selected[0]
				#~ #puts selection.selected.path
				#~ #true
			#~ elsif path_currently_selected
				#~ puts selection.selected[0]
				#~ true
			#~ else
				#~ true
			#~ end
		#~ end

		renderer = Gtk::CellRendererText.new
		
		col = Gtk::TreeViewColumn.new("", renderer, :text => 0)
		@preferencesbar.append_column(col)
		@preferencesbar.expand_all
		#@treeselection.select_path(Gtk::TreePath.new("0:0"))
		@treeselection.select_iter(child2)
		@currentcategory = @configarea.child
		puts @currentcategory
		draw_category(@categories['Layout'])
		@configarray = {}
		
		#puts @glade['message'].class
		fill_values
	end
	
	def fill_values
		values = $config.get_all_values
		
		values.each do | key, value|
			if @glade[key]
				if @glade[key].class == Gtk::Entry
					@glade[key].text = value
					@glade[key].signal_connect('changed') do |widget|
						change_setting(widget, widget.text)
					end
					@configarray[@glade[key]] = {'name' => key, 'value' => value}
				elsif @glade[key].class == Gtk::ComboBox
					i = 0
					#fill the combobox
					@configarray[@glade[key]] = {'name' => key, 'value' => value}
					@options[key].each do |v|
						@channellistposition.append_text(v)
						if value == v.downcase
							@channellistposition.active = i
						end
						i += 1
					end
					#if @glade[key].active == 0
					#	@glade[key].active = 1
					#end
				elsif @glade[key].class == Gtk::Button and value.class == Gdk::Color
					color_button(@glade[key], value)
					@configarray[@glade[key]] = {'name' => key, 'value' => value}
				end
			end
		end
		#@glade['message'].text = @config['message']
	end
	
	def color_button(button, color)
		button.modify_bg(Gtk::STATE_NORMAL, color)
	end
	
	def switch_category(selection)
		draw_category(@categories[selection[0]]) if @categories[selection[0]] and selection
	end
	
	def draw_category(category)
		puts category, @currentcategory
		@configarea.remove(@currentcategory)
		@configarea.add(category)
		@currentcategory = category
	end

	def change_setting(widget, setting)
		puts 'changed setting of '+widget.name
		@configarray[widget] = {'name' => widget.name, 'value' => setting}
	end
	
	def change_color(widget, color)
		color_button(widget, color)
		change_setting(widget, color)
		#$config.set_value(widget.name, color)
	end
	
	def select_color(widget)
		button = widget
		@configarray[widget] = {'name' => widget.name} unless @configarray[widget]
		color = nil
		color = @configarray[widget]['value'] if @configarray[widget]['value']

		selectordialog = Gtk::ColorSelectionDialog.new
		selectordialog.modal = true
		selector = selectordialog.colorsel
		if color
			selector.current_color = color
			selector.previous_color = color
		end
		selectordialog.run do |response|
		case response
			when Gtk::Dialog::RESPONSE_OK
				change_color(button, selector.current_color)
			#else
				#do_nothing_since_dialog_was_cancelled()
			end
			selectordialog.destroy
		end
	end
	
	def combobox_changed(widget)
		puts @options[widget.name][widget.active]
		change_setting(widget, @options[widget.name][widget.active].downcase)
		#@configarray[widget] = {'name' => widget.name, 'value' => @options[widget.name][widget.active]}
	end
	
	def update_config
		#pass all the values back to $config
		@configarray.each do |k, v|
			$config.set_value(v['name'], v['value'])
		end
		destroy
		$main.window.draw_from_config
		$config.send_config
	end
	
	def show_all
		@window.show_all
	end
	
	def destroy
		@window.destroy
	end
	
end