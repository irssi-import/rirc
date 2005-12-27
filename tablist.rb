#~ require 'gtk2'
#~ require 'monitor'
#~ require 'scw'
#~ require 'orderedhash'
#~ require 'main'
#~ require 'observer'

#~ Gtk::init

#~ $config = Configuration.new

#~ $main = Main.new

GLOBAL = 0
LOCAL = 1

LAST_ACTIVITY = 2
LAST_USER_ACTIVITY = 3



class TabListModel
    include Observable
    attr_reader :root, :tree, :structure, :active, :status
    def initialize(root=nil, structure=HIERARCHICAL, sort=INSENSITIVE)
        @predefined = ['#cataclysm-software', 'Vagabond']
        @tree = OrderedHash.new
        #set things up, I guess build the way the buffers are stored, load the search stuff, set up the numbering
        #all widgets are stored in here, NOT the buffer object
        #so we build a tree of buffers (there's always one level of hierarchy), sort and number it accordingly
        #we then do adds/removes/resorts and update the widgets
        #the classes doing the actual widgets will be children of this class, like *Box and TreeView
        #do >1 levels of hierarchy make sense? (probably only for treeview)
        @structure = structure
        @sort = sort
        @root = root
        @numbers = []
        @status = {}
        @active = root
        @tree = construct_tree if root
        
        #draw_tree if root
    end
    
    def root=(root)
        @root = root
        @tree = construct_tree if root
    end
    
    def set_sort_and_structure(structure, model)
        return if @structure == structure and @sort == model
        @structure = structure
        @sort = model
        tree = construct_tree
        if tree
            @tree = tree
            changed
            notify_observers(:redraw, nil)
        end
    end
    
    def structure=(structure)
        return if @structure == structure
        @structure = structure
        tree = construct_tree
        if tree
            @tree = tree
            changed
            notify_observers(:redraw, nil)
        end
    end
    
    def sort=(model)
        return if @sort == model
        @sort = model
        tree = construct_tree
        if tree
            @tree = tree
            changed
            notify_observers(:redraw, nil)
        end
    end
    
    def construct_tree
        #move these into blocks and store them as constants? would allow pluggable structure & sort methods...
        if @structure == FLAT
            @numbers = []
            tree = OrderedHash.new
            tree[@root] = []
            v= []
            bleh = []
            @root.servers.select{|e| e.connected}.each do |x|
                bleh.push([x])
            end
            bleh.sort(&@sort).each do |x|
                x = x[0]
                v += (x.channels+x.chats).select{|e| e.connected}
            end

            tree[@root] = sort_with_predefined(v)
            
            tree[@root].each {|c, o| @numbers.push(c) if o == 0}
            return tree
        elsif @structure == HIERARCHICAL
            @numbers = []
            tree = OrderedHash.new
            tree[@root] = OrderedHash.new
            bleh = []
            @root.servers.select{|e| e.connected}.each do |x|
                bleh.push([x])
            end
            bleh.sort(&@sort).each do |x|
                x = x[0]
                tree[@root][x] = sort_with_predefined((x.channels+x.chats).select{|e| e.connected})
                
                tree[@root][x].each {|c, b| @numbers.push(c)}
            end
            return tree
        else
            puts 'invalid structure algorithim'
            puts structure
            return nil
        end
    end
    
    def sort_with_predefined(array)
        if array.class == Array
            temp = OrderedHash.new
            array.each{|e| temp.push(e, 0) unless e == 0}
            array = temp
        end
        result = OrderedHash.new
        temp = []
        pre = array.select{|e, b| @predefined.include?(e.name)}
        post = array.select{|e, b| !@predefined.include?(e.name)}
        pre.each do |item, b|
            j = 0
            @predefined.each_with_index do |p, i|
                if item.name == p
                    j = i
                end
            end
            temp[j] = item
        end
        temp.compact!
        post.sort(&@sort).each {|item, b| temp.push(item)}
        
        temp.each{|e| result[e] = 0}
        
        return result
    end
    
    def add(item, group=false)
        #puts caller
        #puts item.name
        if @structure == FLAT
            if @root.servers.include?(item)
                (item.channels+item.chats).each {|e| add(e, true)}
                changed
                notify_observers(:add, item)
            else
                x = @tree[@root]
                x.push(item, 0)
                y = sort_with_predefined(x)
                y.each_with_index do |z, i|
                    if z[0] == item
                        @numbers.insert(i, item)
                    end
                end
                @tree[@root] = y
                unless group
                    changed
                    notify_observers(:add, item)
                end
            end
        elsif @structure == HIERARCHICAL
            if @root.servers.include?(item)
                temp = OrderedHash.new
                
                stuff = []
                @tree[@root].each do |x, y|
                    stuff.push([x])
                end
                
                stuff.push([item])

                stuff.sort(&@sort).each do |x|
                    if x[0] == item
                        temp.push(x[0], OrderedHash.new)
                    else
                        temp.push(x[0], @tree[@root][x[0]])
                    end
                end

                @tree[@root] = temp
                (item.channels+item.chats).each {|e| add(e, true) if e.connected}
                changed
                notify_observers(:add, item)
            else
                @tree[@root].each do |s, l|

                    if (s.channels+s.chats).include?(item)
                        x = OrderedHash.new
                        l.each do |a, b|
                            x.push(a, b)
                        end
                        x.push(item, 0)
                        y = sort_with_predefined(x)
                        #puts 
                        #y.each {|k, v| puts k.name}
                        #puts 
                        #puts tab2number(y.keys[0])
                        y.each_with_index do |z, i|
                            #puts z[0].name
                            if z[0] == item
                                if i > 0
                                    #puts i
                                    #puts tab2number(y.keys[i-1])
                                    @numbers.insert(tab2number(y.keys[i-1]), item)
                                #elsif i == 0
                                #   #puts 'foo'
                                #   num =  tab2number(y.keys[0])
                                #   num ||= 0
                                #   @numbers.insert(num, item)
                                else
                                    #puts z[0].name+'foo'
                                    if y.length == 1
                                        if prev_server(s)
                                            v = @tree[@root][prev_server(s)]
                                            num = tab2number(v[-1])
                                            #puts num
                                        else
                                            num = 0
                                        end
                                        #@numbers.insert(num, item) if num
                                    else
                                        num = tab2number(l[0])
                                        if num
                                            num -= 1
                                            #puts num
                                        end
                                        #@numbers.insert(tab2number(l[0])-1, item) if tab2number(l[0])
                                    end
                                    unless num
                                        #num =  tab2number(y.keys[0])
                                        #num ||= 0
                                        num = @numbers.length+1 - x.length
                                        #puts num
                                    end
                                    #puts num
                                    @numbers.insert(num, item)
                                end
                                if @tree[@root].class == Array
                                end
                                @tree[@root][s] = y
                            end
                        end
                    end
                end
                unless group
                    changed
                    notify_observers(:add, item)
                end
            end
        end
    end
    
    def setstatus(item, level)
        return unless item
		if !@status[item] or level > @status[item] or level == 0
            #puts 'setting status of '+item.name+' to '+level.to_s
			@status[item] = level
            changed
            notify_observers(:setstatus, item, level)
        else
            #puts 'not setting status of '+item.name+' to '+level.to_s
            #puts level, @status[item]
        end
    end
    
    def set_active(item)
        setstatus(item, ACTIVE)
        @active.marklastread if @active
        oldactive = @active
        changed
        notify_observers(:set_active, item)
        @active = item
        setstatus(oldactive, INACTIVE)
    end
    
    def prev_server(current)
        prev = nil
        @tree[@root].each do |s, l|
            if current == s
                return prev
            end
            prev = s
        end
        return prev
    end
    
    def remove(item)
        if !@structure == FLAT
            if @root.servers.include?(item)
                item
                (item.channels+item.chats).each do |e|
                    @numbers.delete(e)
                    @tree[@root].delete(e)
                    changed
                    notify_observers(:remove, e)
                end
                @numbers.compact!
            else
                @numbers.delete(item)
                @tree[@root].delete(item)
                changed
                notify_observers(:remove, item)
                @numbers.compact!
            end
        elsif @structure == HIERARCHICAL
            if @root.servers.include?(item)
                @tree[@root].delete(item)
                changed
                notify_observers(:remove, item)
                (item.channels+item.chats).each do |e|
                    @numbers.delete(e)
                    changed
                    notify_observers(:remove, e)
                end
                @numbers.compact!
            else
                @tree[@root].each do |e, l|
                    if l.include?(item)
                        l.delete(item)
                        @numbers.delete(item)
                        changed
                        notify_observers(:remove, item)
                        @numbers.compact!
                    end
                end
            end
        end
    end
    
    def number2tab(num)
        return @numbers[num.to_i-1]
    end
    
    def tab2number(tab)
        if @numbers.include?(tab)
            result = @numbers.index(tab)+1
        end
        return result ||= nil
    end
    
    def draw_tree
        puts @root.name
        @tree[@root].each do |a, b|
            puts "\t"+a.name if @structure != FLAT
            if b.methods.include?('each')
                b.each do |c, d|
                    next if c == 0
                    puts "\t\t"+tab2number(c).to_s+':'+c.name
                end
            else
                puts "\t"+tab2number(a).to_s+':'+a.name if @structure == FLAT
            end
        end
    end
end

class TabList
    attr_reader :model
    def initialize(model)
        @model = model
        model.add_observer(self)
    end
    
    def update(action, tab, option=nil)
        if action == :add
            add(tab)
        elsif action == :remove
            remove(tab)
        elsif action == :setstatus
            setstatus(tab, option)
        elsif action == :set_active
            set_active(tab)
        elsif action == :redraw
            redraw
        end
    end
    
    def redraw
        puts 'redraw triggered'
        clear
        fill
        set_active(@model.active)
        #widget.show_all
    end
    
    def setstatus(buffer, status)
        #~ return unless buffer
		#~ if !@model.status[buffer] or status > @model.status[buffer] or status == 0
            #~ puts 'setting status of '+buffer.name+' to '+status.to_s
			#~ @model.status[buffer] = status
			#~ recolor(buffer)
        #~ else
            #~ puts 'not setting status of '+buffer.name+' to '+status.to_s
            #~ puts status, @model.status[buffer]
        #~ end
        recolor(buffer)
	end
end
    

class BoxTabList < TabList
    def initialize(model)
        super
        @buttons = {}
        @togglehandlers = {}
        fill
        @box.show_all
        
        #set_active(model.active)
    end
    
    def widget
        return @box
    end
    
    def fill
        @box.pack_start(add_button(@model.root), false, false)
        add_seperator
        b = nil
        @model.tree[@model.root].each do |k, v|
            @box.pack_start(add_button(k), false, false)
            recolor(k)
            if v.methods.include?('each')
                v.each do |z, c|
                    @box.pack_start(add_button(z), false, false)
                    recolor(z)
                end
                add_seperator
            else
            end
        end
        cleanup
    end
    
    def clear
        @buttons = {}
        @togglehandlers = {}
        @box.children.each {|child| @box.remove(child)}
    end
    
    def add(tab)
        x = []
        x.push(add_button(@model.root))
        x.push(create_seperator)
        b = nil
        @model.tree[@model.root].each do |k, v|
            x.push(add_button(k))
            if v.methods.include?('each')
                v.each do |z, c|
                    x.push(add_button(z))
                end
                x.push(create_seperator)
            else
            end
        end
        #puts x.length
        #puts @box.children.length
        i = 0
        prev = nil
        
        @box.children.each do |child|
            if child.class.ancestors.include?(Gtk::Separator) and x[i].class.ancestors.include?(Gtk::Separator)
                prev = x[i]
                i += 1
                next
            end
            if child == x[i]
            else
                if x[i]
                    if x[i].class.ancestors.include?(Gtk::Separator)
                        @box.pack_start(x[i], false, false, 5)
                    else
                        @box.pack_start(x[i], false, false)
                    end
                    @box.reorder_child(x[i], i)
                end
            end
            i += 1
            prev = child
        end
        while i < x.length
            if prev.class.ancestors.include?(Gtk::Separator) and x[i].class.ancestors.include?(Gtk::Separator)
                #puts prev, x[i]
                prev = x[i]
                i += 1
                next
            end
            if x[i].class.ancestors.include?(Gtk::Separator)
                @box.pack_start(x[i], false, false, 5)
            else
                @box.pack_start(x[i], false, false)
            end
            @box.reorder_child(x[i], i)
            prev = x[i]
            i+=1
        end
        cleanup
        renumber
        #@box.show_all
    end
        
    def remove(tab)
    
        if @buttons[tab]
            @box.remove(@buttons[tab])
            @buttons.delete(tab)
        end
        renumber
        cleanup
    end
    
    #Ack, why oh why can't I code an insert that doesn't need a cleanup?
    def cleanup
        #removes double and trailing seperators
        prev = nil
        @box.each do |child|
            if child.class.ancestors.include?(Gtk::Separator) and prev.class.ancestors.include?(Gtk::Separator)
                @box.remove(child)
                prev = nil
            else
                prev=child
            end
        end
        if @box.children[-1].class.ancestors.include?(Gtk::Separator)
            @box.remove(box.children[-1])
        end
    end
    
    def renumber
        @buttons.each do |buffer, button|
            number = ''
            if $config['numbertabs'] and x = @model.tab2number(buffer)
                number = x.to_s+':'
            end
            
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
            #oldactive = @model.active
        end
        #setstatus(@active, ACTIVE)
        #@model.active = buffer
        #setstatus(oldactive, INACTIVE) if oldactive
        
        @buttons[buffer].signal_handler_block(@togglehandlers[buffer])
        @buttons[buffer].active = true
        @buttons[buffer].signal_handler_unblock(@togglehandlers[buffer])
        $main.window.switchchannel(buffer) if $main.window
    end
    
	def recolor(buffer)
        return unless @buttons[buffer]
        label = @buttons[buffer].child
        if buffer == @model.active
            label.modify_fg(Gtk::STATE_NORMAL, Gdk::Color.new(*$config.getstatuscolor(0)))
            label.modify_fg(Gtk::STATE_PRELIGHT, Gdk::Color.new(*$config.getstatuscolor(0)))
        else
            label.modify_fg(Gtk::STATE_NORMAL, Gdk::Color.new(*$config.getstatuscolor(@model.status[buffer])))
            label.modify_fg(Gtk::STATE_PRELIGHT, Gdk::Color.new(*$config.getstatuscolor(@model.status[buffer])))
        end
	end
    
    def add_button(buffer)
        if !@buttons.include?(buffer)
            number = ''
            if $config['numbertabs'] and x = @model.tab2number(buffer)
                number = x.to_s+':'
            end
            button = Gtk::ToggleButton.new(number+buffer.name)
                
            @togglehandlers[buffer] = button.signal_connect('toggled')do |w|
                #puts 'activated  '+buffer.name
                @model.set_active(buffer)
            end
            button.signal_connect('button_press_event')do |w, event|
                if event.button == 3
                    buffer.rightclickmenu(event)
                end
            end
            @buttons[buffer] = button
            button.show
        end
        return @buttons[buffer]
    end
end

class VBoxTabList < BoxTabList
    attr_reader :box
    def initialize(model)
        @box = Gtk::VBox.new
        super
    end
    
    def create_seperator
        b = Gtk::HSeparator.new
        b.show
        return b
    end
    
    def add_seperator
        b = Gtk::HSeparator.new
        @box.pack_start(b, false, false, 5)
        b.show
        return b
    end
end

class HBoxTabList < BoxTabList
    attr_reader :box
    def initialize(model)
        @box = Gtk::HBox.new
        super
    end
    
    def create_seperator
        b = Gtk::VSeparator.new
        b.show
        return b
    end
    
    def add_seperator
        b = Gtk::VSeparator.new
        @box.pack_start(b, false, false, 5)
        b.show
        return b
    end
end

class TreeTabList < TabList
    attr_reader :model, :view
    def initialize(model)
        super
        @store = Gtk::TreeStore.new(String, String)
        @view = Gtk::TreeView.new(@store)
        @selecthandler = @view.selection.signal_connect('changed') do |w|
            @model.set_active(iter2buffer(w.selected))
        end
        @iters = {}
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
        #set_active(model.root)
        set_active(model.active)
        @view.signal_connect('focus_in_event') do |w, event|
            set_active(@model.active)
        end
        @view.signal_connect('button_press_event') do |w, event|
            if event.button == 3
                @model.active.rightclickmenu(event) if @model.active
            end
        end
    end
    
    def widget
        return @sw
    end
    
    def fill
        parent = add_iter(@model.root)
        @model.tree[@model.root].each do |k, v|
            child = add_iter(k, parent)
            @view.expand_row(parent.path, false)
            recolor(k)
            if v.methods.include?('each')
                v.each do |z, c|
                    child2 = add_iter(z, child)
                    @view.expand_row(child.path, false)
                    recolor(z)
                end
            else
            
            end
        end
        cleanup
    end
    
    def clear
        @iters = {}
        @store.clear
    end
    
    def add(item)
        i = 0
        @model.tree[@model.root].each do |k, v|
            path = '0:'+i.to_s
            this = @store.get_iter(path)
            if this and clean_tag(this[1]) != k.name
                new = @store.insert_before(@store.get_iter(@iters[@model.root].path), this)
                new[1] = k.name
                @iters[k] = Gtk::TreeRowReference.new(@store, new.path)
                @view.expand_row(@iters[@model.root].path, false)
            elsif !this
                new = @store.insert_before(@store.get_iter(@iters[@model.root].path), nil)
                new[1] = k.name
                @iters[k] = Gtk::TreeRowReference.new(@store, new.path)
                @view.expand_row(@iters[@model.root].path, false)
            end
            j = 0
            if v.methods.include?('each')
                v.each do |z, c|
                    path2 = '0:'+i.to_s+':'+j.to_s
                    this2 = @store.get_iter(path2)
                    if this2 and clean_tag(this2[1]) != z.name
                        #puts path2, z.name
                        new = @store.insert_before(@store.get_iter(@iters[k].path), this2)
                        new[1] = z.name
                        @iters[z] = Gtk::TreeRowReference.new(@store, new.path)
                        @view.expand_row(this.path, false)
                    elsif !this2
                        path2 = '0:'+i.to_s+':'+(j-1).to_s
                        new = @store.insert_before(@store.get_iter(@iters[k].path), nil)
                        new[1] = z.name
                        @iters[z] = Gtk::TreeRowReference.new(@store, new.path)
                        @view.expand_row(this.path, false)
                    end
                    j += 1
                end
            end
            i += 1
        end
        cleanup
        renumber
    end
    
    #ack, I wish I didn't need this
    def cleanup
        @store.each do |model, path, iter|
            if !iter2buffer(iter)
                @store.remove(iter)
            end
        end
    end
    
    def remove(item)
        if @iters[item] and @iters[item].valid?
            @store.remove(@store.get_iter(@iters[item].path))
            @iters.delete(item)
        end
    end
    
    def renumber
        @iters.each do |buffer, iter|
            y = @store.get_iter(iter.path)
            number = ''
            if $config['numbertabs'] and x = @model.tab2number(buffer)
                number = x.to_s
            end
            y[0] = number
        end
    end
           
    
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
        if $config['numbertabs'] and x = @model.tab2number(buffer)
            number = x.to_s
        end
        iter[0] = number
        iter[1] = buffer.name
        @iters[buffer] = Gtk::TreeRowReference.new(@store, iter.path)
        return iter
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
            setstatus(buffer, ACTIVE)
            @active = buffer
            setstatus(oldactive, INACTIVE) if oldactive
            
            @view.selection.signal_handler_block(@selecthandler)
            @view.selection.select_iter(@store.get_iter(@iters[buffer].path)) if @iters[buffer]
            @view.selection.signal_handler_unblock(@selecthandler)
            $main.window.switchchannel(buffer) if $main.window
        end
    end
    
    def recolor(buffer)
        return if buffer == @model.active
        if @iters[buffer] and @iters[buffer].valid?
            iter = @store.get_iter(@iters[buffer].path)
            if @model.status[buffer] > 0
                color = $config.getstatuscolor(@model.status[buffer]).to_hex
                iter[1] = '<span color="'+color+'">'+clean_tag(iter[1])+'</span>'
                #puts 'recoloring '+buffer.name
            else
                iter[1] = clean_tag(iter[1])
                #puts 'not recoloring active buffer '+buffer.name
            end
        end
    end
end

#~ root = RootBuffer.new(self)

#~ free = root.add('freenode', 'Vagabond')
#~ free.add('#irssi2')
#~ free.add('#Wings3d')
#~ free.add('#trotw')
#~ free.addchat('Vagabond')

#~ quake = root.add('Quakenet', 'Vagabond')
#~ quake.add('#cataclysm-software')


#~ puts 'Forcing #cataclysm-software and Vagabond to sort first'

#~ puts "\nHierarchical, case insensitive, hashes\n"
#~ x = TabList.new(root)

#~ puts "\nHierarchical, case insensitive, no hashes\n"
# x = TabList.new(root, HIERARCHICAL, GLOBAL, ALPHA_INSENSITIVE_NOHASH)

#~ puts "\nHierarchical, case sensitive, hashes\n"
#~ x = TabList.new(root, HIERARCHICAL, GLOBAL, ALPHA_SENSITIVE)

#~ puts "\nHierarchical, case sensitive, no hashes\n"
#~ x = TabList.new(root, HIERARCHICAL, GLOBAL, ALPHA_SENSITIVE_NOHASH)

#~ puts "\nFlat, case insensitive, hashes\n"
#~ x = TabList.new(root, FLAT)

#~ puts "\nFlat, case insensitive, no hashes\n"
#~ x = TabList.new(root, FLAT, GLOBAL, ALPHA_INSENSITIVE_NOHASH)

#~ puts "\nFlat, case sensitive, hashes\n"
#~ x = TabList.new(root, FLAT, GLOBAL, ALPHA_SENSITIVE)

#puts "\nFlat, case sensitive, no hashes\n"
#x = TabListModel.new(root, true, GLOBAL, ALPHA_INSENSITIVE)

#x.remove(free)

#~ x.draw_tree

#~ p =HBoxTabList.new(x)

#~ Gtk::Window.new.add(p.box).show_all

#~ p =VBoxTabList.new(x)

#~ Gtk::Window.new.add(p.box).show_all


#~ x = TabListModel.new(root, true, GLOBAL, ALPHA_INSENSITIVE)

#~ p =HBoxTabList.new(x)

#~ Gtk::Window.new.add(p.box).show_all

#p =TreeTabList.new(x)

#Gtk::Window.new.add(p.view).show_all

#~ x = TabListModel.new(root, false, GLOBAL, ALPHA_INSENSITIVE)

#~ p =VBoxTabList.new(x)

#~ Gtk::Window.new.add(p.box).show_all

#~ p =TreeTabList.new(x)

#~ Gtk::Window.new.add(p.view).show_all

#~ b = root.add('EFnet', 'Vagabond')
#~ c = b.add('foo')
#x.add(b)

#~ x.add(free.add('#cackooking'))

#~ x.add(free.add('#aardvark'))
#~ x.add(free.add('#zztop'))

#~ Thread.new do
#~ sleep 5
#puts 'go time'
#~ x.add(b)
#~ sleep 1
#~ p.set_active(c)
#~ x.setstatus(c, 2)
#~ sleep 4
#x.setstatus(c, 4)
#x.remove(quake)
#x.draw_tree
#~ end

#x.draw_tree

#~ Gtk::main