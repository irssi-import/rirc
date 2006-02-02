#the base view class...
class BufferListView
    attr_reader :model
    def initialize(controller, model)
        @controller = controller
        @model = model
        @filled = false
    end

    def filled?
        @filled
    end

    def rightclickmenu(buffer, event)
        puts buffer
        menu = Gtk::Menu.new
        if buffer.respond_to? :part
            i = Gtk::MenuItem.new('Part')
            i.signal_connect("activate"){buffer.part}
            menu.append(i)
        elsif buffer.respond_to? :disconnect
            i = Gtk::MenuItem.new('Disconnect')
            i.signal_connect("activate"){buffer.disconnect}
            menu.append(i)
        end
        i = Gtk::MenuItem.new("Close")
        i.signal_connect("activate"){buffer.close}
        menu.append(i)
        menu.show_all
        menu.popup(nil, nil, event.button, event.time)
    end



    def redraw
        #         puts 'redraw triggered'
        clear
        fill
        set_active(@model.active)
    end

    def update_status(buffer)
        recolor(buffer)
    end

    #stub for child classes to implement
    def clear
    end

    #stub for child classes to implement
    def fill
    end

    def recolor
    end
end


class BoxBufferListView < BufferListView
    def initialize(controller, model)
        super
        @buttons = {}
        @config = @controller.config
        @togglehandlers = {}
        fill
        #         puts model.active
        set_active(model.active)
        @box.show_all
    end

    def widget
        return @box
    end

    def fill
        clear
        @model.structure.each do |o|
            if !@box.children.empty? and o.class == NetworkBuffer
                add_separator
            end
            @box.pack_start(add_button(o), false)
        end
        @filled = true
    end

    def clear
        @buttons = {}
        @togglehandlers = {}
        @box.children.each {|child| @box.remove(child)}
        @filled = false
    end

    def insert(object, after)
        index = nil
        if after == nil or object == after
            index = 0
        else
            @box.children.each_with_index do |c, i|
                if @buttons.index(c) == after
                    index = i+1
                end
            end
        end

        if index
            #inserting a network after 0, insert a separator before it
            if object.class == NetworkBuffer and index > 0
                s = add_separator
                @box.reorder_child(s, index)
                index +=1
            end
            button = add_button(object)
            @box.pack_start(button, false)
            @box.reorder_child(button, index)
            #inserting a network at 0, add a separator after it...
            if object.class == NetworkBuffer and index == 0 and @box.children.length > 1
                s = add_separator
                @box.reorder_child(s, index+1)
            end
        end
    end

    def remove(object)
        if @buttons[object]
            index = @box.children.index(@buttons[object])
            @box.remove(@buttons[object])
            @buttons.delete(object)
            if @box.children[index-1].class.ancestors.include? Gtk::Separator
                @box.remove(@box.children[index-1])
            elsif @box.children[0].class.ancestors.include? Gtk::Separator
                @box.remove(@box.children[0])
            end
        end
    end

    def renumber
        @buttons.each do |buffer, button|
            number = ''
            #~ if $config['numbertabs'] and x = @model.tab2number(buffer)
            #~ number = x.to_s+':'
            #~ end

            button.label = number+buffer.name
            recolor(buffer)
        end
    end


    def set_active(buffer)
        return unless @buttons[buffer]
        if @model.active and @buttons[@model.active]
            @buttons[@model.active].signal_handler_block(@togglehandlers[@model.active])
            @buttons[@model.active].active = false
            @buttons[@model.active].signal_handler_unblock(@togglehandlers[@model.active])
        end

        @buttons[buffer].signal_handler_block(@togglehandlers[buffer])
        @buttons[buffer].active = true
        @buttons[buffer].signal_handler_unblock(@togglehandlers[buffer])
        #@controller.set_active(buffer)
    end

    def recolor(buffer)
        return unless @buttons[buffer]
        label = @buttons[buffer].child
        if buffer == @model.active
            label.modify_fg(Gtk::STATE_NORMAL, Gdk::Color.new(*@config.getstatuscolor(0)))
            label.modify_fg(Gtk::STATE_PRELIGHT, Gdk::Color.new(*@config.getstatuscolor(0)))
        else
            label.modify_fg(Gtk::STATE_NORMAL, Gdk::Color.new(*@config.getstatuscolor(buffer.status)))
            label.modify_fg(Gtk::STATE_PRELIGHT, Gdk::Color.new(*@config.getstatuscolor(buffer.status)))
        end
    end

    def add_button(buffer)
        if !@buttons.include?(buffer)
            number = ''
            #~ if $config['numbertabs'] and x = @model.tab2number(buffer)
            #~ number = x.to_s+':'
            #~ end
            button = Gtk::ToggleButton.new(number+buffer.name)

            @togglehandlers[buffer] = button.signal_connect('toggled')do |w|
                if buffer == @model.active
                    set_active(buffer)#force it active again
                else
                    @controller.set_active(buffer)
                end
            end
            button.signal_connect('button_press_event')do |w, event|
                if event.button == 3
                    rightclickmenu(buffer, event)
                end
            end
            @buttons[buffer] = button
            button.show
        end
        return @buttons[buffer]
    end

    def add_separator
        b = create_separator
        @box.pack_start(b, false, false, 5)
        b.show
        return b
    end
end

class VBoxBufferListView < BoxBufferListView
    attr_reader :box
    def initialize(controller, model)
        @box = Gtk::VBox.new
        super
    end

    def create_separator
        b = Gtk::HSeparator.new
        b.show
        return b
    end
end

class HBoxBufferListView < BoxBufferListView
    attr_reader :box
    def initialize(controller, model)
        @box = Gtk::HBox.new
        super
    end

    def create_separator
        b = Gtk::VSeparator.new
        b.show
        return b
    end
end

class TreeBufferListView < BufferListView
    attr_reader :model, :view
    def initialize(controller, model)
        super
        @store = Gtk::TreeStore.new(String, String)
        @view = Gtk::TreeView.new(@store)
        @selecthandler = @view.selection.signal_connect('changed') do |w|
            @controller.set_active(iter2buffer(w.selected))
        end
        @iters = {}
        @config = @controller.config
        fill
        renderer = Gtk::CellRendererText.new
        col = Gtk::TreeViewColumn.new("", renderer, :text => 0)
        @view.append_column(col)
        col = Gtk::TreeViewColumn.new("", renderer, :markup => 1)
        @view.append_column(col)
        @view.set_expander_column(col)
        @view.headers_visible=false
        @view.enable_search = false
        @view.expand_all
        @frame = Gtk::Frame.new
        @frame.shadow_type = Gtk::SHADOW_ETCHED_IN
        @frame.add(@view)
        @sw = Gtk::ScrolledWindow.new
        @sw.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
        @sw.add_with_viewport(@frame)
        @sw.show_all
        @view.signal_connect('focus_in_event') do |w, event|
            set_active(@model.active)
        end
        @view.signal_connect('button_press_event') do |widget, event|
            #             if event.button == 3
            #                 rightclickmenu(buffer, event)
            #             end
            if event.button == 3
                path, column, x, y = widget.get_path_at_pos(event.x, event.y)
                if  path
                    puts "path is #{path}"
#                 widget.set_cursor(path, nil, false)
                    foo = @iters.values.detect{|x| x.path.to_s == path.to_s}
                    puts "result #{foo}, #{@iters.index(foo)}"
                    buffer = @iters.index(foo)
                    rightclickmenu(buffer, event) if buffer
                end
                true
            end
        end
    end

    def widget
        @sw
    end

    def fill
        clear
        @model.structure.each do |o|
            if !o.respond_to? :network or o == o.network
                add_iter(o)
            else
                add_iter(o, get_last_parent)
            end
        end
        @filled = true
        #         parent = add_iter(@model.root)
        #         @model.tree[@model.root].each do |k, v|
        #             child = add_iter(k, parent)
        #             @view.expand_row(parent.path, false)
        #             recolor(k)
        #             if v.methods.include?('each')
        #                 v.each do |z, c|
        #                     child2 = add_iter(z, child)
        #                     @view.expand_row(child.path, false)
        #                     recolor(z)
        #                 end
        #             else

        #             end
        #         end
        #         cleanup
    end

    def clear
        @iters = {}
        @store.clear
        @filled = false
    end

    def insert(object, after)
        #         puts after
        path = @iters[after].path
        #         puts path.depth
        if !object.respond_to? :network or object == object.network
            if path.depth == 1
                iter = @store.insert_after(nil, @store.get_iter(path))
            elsif
                iter = @store.insert_after(nil, @store.get_iter(path.indices[0].to_s))
            end
        else
            if path.depth == 1
                iter = @store.insert_after(@store.get_iter(path), nil)
            else
                iter = @store.insert_after(@store.get_iter(path.indices[0].to_s), @store.get_iter(path))
            end
        end
        iter[0] = ''
        iter[1] = object.name
        @iters[object] = Gtk::TreeRowReference.new(@store, iter.path)
        #         exit
    end

    #~ def add(item)
    #~ i = 0
    #~ @model.tree[@model.root].each do |k, v|
    #~ path = '0:'+i.to_s
    #~ this = @store.get_iter(path)
    #~ if this and clean_tag(this[1]) != k.name
    #~ new = @store.insert_before(@store.get_iter(@iters[@model.root].path), this)
    #~ new[1] = k.name
    #~ @iters[k] = Gtk::TreeRowReference.new(@store, new.path)
    #~ @view.expand_row(@iters[@model.root].path, false)
    #~ elsif !this
    #~ new = @store.insert_before(@store.get_iter(@iters[@model.root].path), nil)
    #~ new[1] = k.name
    #~ @iters[k] = Gtk::TreeRowReference.new(@store, new.path)
    #~ @view.expand_row(@iters[@model.root].path, false)
    #~ end
    #~ j = 0
    #~ if v.methods.include?('each')
    #~ v.each do |z, c|
    #~ path2 = '0:'+i.to_s+':'+j.to_s
    #~ this2 = @store.get_iter(path2)
    #~ if this2 and clean_tag(this2[1]) != z.name
    #~ #puts path2, z.name
    #~ new = @store.insert_before(@store.get_iter(@iters[k].path), this2)
    #~ new[1] = z.name
    #~ @iters[z] = Gtk::TreeRowReference.new(@store, new.path)
    #~ @view.expand_row(this.path, false)
    #~ elsif !this2
    #~ path2 = '0:'+i.to_s+':'+(j-1).to_s
    #~ new = @store.insert_before(@store.get_iter(@iters[k].path), nil)
    #~ new[1] = z.name
    #~ @iters[z] = Gtk::TreeRowReference.new(@store, new.path)
    #~ @view.expand_row(this.path, false)
    #~ end
    #~ j += 1
    #~ end
    #~ end
    #~ i += 1
    #~ end
    #~ cleanup
    #~ renumber
    #~ end

    #~ #ack, I wish I didn't need this
    #~ def cleanup
    #~ @store.each do |model, path, iter|
    #~ if !iter2buffer(iter)
    #~ @store.remove(iter)
    #~ end
    #~ end
    #~ end

    #~ def remove(item)
    #~ if @iters[item] and @iters[item].valid?
    #~ @store.remove(@store.get_iter(@iters[item].path))
    #~ @iters.delete(item)
    #~ end
    #~ end

    #~ def renumber
    #~ @iters.each do |buffer, iter|
    #~ y = @store.get_iter(iter.path)
    #~ number = ''
    #~ if $config['numbertabs'] and x = @model.tab2number(buffer)
    #~ number = x.to_s
    #~ end
    #~ y[0] = number
    #~ end
    #~ end


    def clean_tag(tag)
        re = /^\<span .+\>(.+?)\<\/span\>$/i
        md = re.match(tag)
        if md
            return md[1]
        else
            return tag
        end
    end

    def add_iter(buffer, parent= nil)
        iter = @store.append(parent)
        number = ''
        #         if $config['numbertabs'] and x = @model.tab2number(buffer)
        #             number = x.to_s
        #         end
        iter[0] = number
        iter[1] = buffer.name
        @iters[buffer] = Gtk::TreeRowReference.new(@store, iter.path)
        return iter
    end

    def get_last_parent(pos=-1)
        #         @iters.values.sort_by.sort_by{|x| [x.split(':')[0].to_i*-1, x.path.length]}[0].path.split(':')[0]
        puts @iters.values.inspect
        root = @iters.values.map{|x| x.path.to_s.split(':')[0]}.sort[pos]
        @store.get_iter(root)
    end

    def iter2buffer(iter)
        return nil unless iter
        @iters.each do |b, i|
            if (i.path.to_s) == (iter.path.to_s)
                return b
            end
        end
        return nil
    end

    def set_active(buffer)
        if buffer
            if @active
                oldactive = @active
            end
            #             setstatus(buffer, ACTIVE)
            @active = buffer
            #             setstatus(oldactive, INACTIVE) if oldactive

            @view.selection.signal_handler_block(@selecthandler)
            @view.selection.select_iter(@store.get_iter(@iters[buffer].path)) if @iters[buffer]
            @view.selection.signal_handler_unblock(@selecthandler)
            recolor(buffer)
            #             $main.window.switchchannel(buffer) if $main.window
        end
    end

    def recolor(buffer)
        if @iters[buffer] and @iters[buffer].valid?
            iter = @store.get_iter(@iters[buffer].path)
            if @model.active == buffer
                iter[1] = clean_tag(iter[1])
            else
                color = @config.getstatuscolor(buffer.status).to_hex
                iter[1] = '<span color="'+color+'">'+clean_tag(iter[1])+'</span>'
                #puts 'recoloring '+buffer.name
            end
        end
    end
end
