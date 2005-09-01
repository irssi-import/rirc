
class LinkWindow
    def initialize(links)
        @glade = GladeXML.new("glade/linkwindow.glade") {|handler| method(handler)}
        @linkstore = Gtk::ListStore.new(String)#, String)
        @linklist = @glade['linklist']
        @linklist.model = @linkstore
		renderer = Gtk::CellRendererText.new
		
		col = Gtk::TreeViewColumn.new("Link", renderer, :text => 0)
		@linklist.append_column(col)
        
        links.each do |x|
            iter = @linkstore.append
            iter[0] = x
        end
        
        @window = @glade['linkwindow']
		#~ col = Gtk::TreeViewColumn.new("Link", renderer, :text => 0)
		#~ @linklist.append_column(col)
        @linklist.selection.signal_connect('changed') do |widget|
            selection = widget.selected
            if selection
                @glade['link_open'].sensitive = true
            else
                @glade['link_open'].sensitive = true
            end
        end
    end
    
    def open_link
        selection = @linklist.selection.selected
        if selection
            go_link(selection[0])
        end
    end
    
    def link_activated(treeview, path, column)
        iter = @linklist.model.get_iter(path)
        if iter
            go_link(iter[0])
        end
    end
    
    def go_link(link)
        system($config['linkclickaction'].sub('%s', $main.window.to_uri(link)))
    end
    
    def destroy
        @window.destroy
    end
end