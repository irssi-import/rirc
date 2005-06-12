
class ConfigWindow
	def initialize
		@glade = GladeXML.new("glade/config.glade") {|handler| method(handler)}
		@window = @glade['config']
		@preferencesbar = @glade['preferencesbar']
		@treestore = Gtk::TreeStore.new(String)
		@preferencesbar.model = @treestore
		@treeselection = @preferencesbar.selection
		@treeselection.signal_connect('changed') do |widget|
			switch_category(widget.selected)
		end
		
		parent = @treestore.append(nil)
		parent[0] = "Interface"
		child1 = @treestore.append(parent)
		child1[0] = "Prompts"
		child2 = @treestore.append(parent)
		child2[0] = "Colors"
		
		@categories = {'Prompts'=>@glade['promptconfig'], 'Colors' => @glade['colorconfig']}
		
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
		
		col = Gtk::TreeViewColumn.new("First Name", renderer, :text => 0)
		@preferencesbar.append_column(col)
		@preferencesbar.expand_all
		@treeselection.select_path(Gtk::TreePath.new("0:0"))
	end
	
	def switch_category(selection)
		draw_category(@categories[selection[0]]) if @categories[selection[0]] and selection
	end
	
	def draw_category(category)
		#todo - oh this is gonna be fun.....
	end
	
	def show_all
		@window.show_all
	end
	
	def hide
		@window.hide
	end
end