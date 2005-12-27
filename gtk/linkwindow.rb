
class LinkWindow
    def initialize(links)
        @glade = GladeXML.new("glade/linkwindow.glade") {|handler| method(handler)}
        @linkstore = Gtk::ListStore.new(String, String, String)
        @linklist = @glade['linklist']
        @linklist.model = @linkstore
        renderer = Gtk::CellRendererText.new
        
        col = Gtk::TreeViewColumn.new("Time", renderer, :text => 0)
        @linklist.append_column(col)
        col = Gtk::TreeViewColumn.new("User", renderer, :text => 1)
        @linklist.append_column(col)
        @linklist.search_column=1
        col = Gtk::TreeViewColumn.new("Link", renderer, :text => 2)
        @linklist.append_column(col)
        
        @links = links
        
        @links.each do |v|
            iter = @linkstore.append
            iter[2] = v['link']
            iter[0] = v['time']
            iter[1] = v['name']
        end
        
        @columns = @linklist.columns
        
        @columnselect = @glade['columnselect']
        
        @columns.each do |column|
            @columnselect.insert_text(0, column.title)
        end
        @columnselect.active = 2
        @filtertext = ''
        
        #~ col.set_cell_data_func(renderer) do |col, renderer, model, iter|
            #~ index = nil
            #~ @columns.each_with_index do |col, i|
                #~ if col.title == @columnselect.active_iter[0]
                    #~ index = i
                #~ end
            #~ end
            
            #~ if index
                #~ if iter[index][0...@filtertext.length] == @filtertext or @filtertext == ''
                #~ else
                    #~ #puts ' I\'d love to remove '+iter.to_s
                    #~ #model.remove(iter)
                    #~ @ditchables.push(iter)
                #~ end
            #~ end
        #~ end
        
        @window = @glade['linkwindow']

        @linklist.selection.signal_connect('changed') do |widget|
            selection = widget.selected
            if selection
                @glade['link_open'].sensitive = true
            else
                @glade['link_open'].sensitive = true
            end
        end
    end
    
    def filter_changed(widget)
        @filtertext = widget.text
        @linkstore.clear
        
        index = nil
        @columns.each_with_index do |col, i|
            if col.title == @columnselect.active_iter[0]
                index = i
            end
        end
        @links.each do |v|
            iter = @linkstore.append
            iter[2] = v['link']
            iter[0] = v['time']
            iter[1] = v['name']
            if iter[index][0...@filtertext.length] == @filtertext or @filtertext == ''
            else
                @linkstore.remove(iter)
            end
        end
        #@linklist.signal_emit('changed')
    end
    
    def open_link
        selection = @linklist.selection.selected
        if selection
            go_link(selection[2])
        end
    end
    
    def link_activated(treeview, path, column)
        iter = @linklist.model.get_iter(path)
        if iter
            go_link(iter[2])
        end
    end
    
    def go_link(link)
        system($config['linkclickaction'].sub('%s', $main.window.to_uri(link)))
    end
    
    def destroy
        @window.destroy
    end
end