#~ require 'gtk2'
#~ require 'monitor'
#~ require 'scw'
#~ require 'orderedhash'
#~ require 'main'
#~ require 'observer'

#~ Gtk::init

#~ $config = Configuration.new

#~ $main = Main.new

HIERARCHICAL = 0
FLAT = 1

GLOBAL = 0
LOCAL = 1

ALPHA_SENSITIVE = Proc.new {|x, y| x[0].name <=> y[0].name}
ALPHA_SENSITIVE_NOHASH = Proc.new {|x, y| x[0].name.sub('#', '') <=> y[0].name.sub('#', '')}
ALPHA_INSENSITIVE = Proc.new {|x, y| x[0].name.downcase <=> y[0].name.downcase}
ALPHA_INSENSITIVE_NOHASH = Proc.new {|x, y| x[0].name.downcase.sub('#', '') <=> y[0].name.downcase.sub('#', '')}

LAST_ACTIVITY = 2
LAST_USER_ACTIVITY = 3



class TabListModel
    include Observable
    attr_reader :root, :tree, :networks
    def initialize(root, networks=true, numbering=GLOBAL, sort=ALPHA_INSENSITIVE)
        @predefined = ['#cataclysm-software', 'Vagabond']
        @tree = OrderedHash.new
        #set things up, I guess build the way the buffers are stored, load the search stuff, set up the numbering
        #all widgets are stored in here, NOT the buffer object
        #so we build a tree of buffers (there's always one level of hierarchy), sort and number it accordingly
        #we then do adds/removes/resorts and update the widgets
        #the classes doing the actual widgets will be children of this class, like *Box and TreeView
        #do >1 levels of hierarchy make sense? (probably only for treeview)
        @networks = networks
        @sort = sort
        @numbering = numbering
        @root = root
        @numbers = []
        @tree = construct_tree
        
        draw_tree
    end
    
    def construct_tree
        #move these into blocks and store them as constants? would allow pluggable structure & sort methods...
        if !@networks
            @numbers = []
            tree = OrderedHash.new
            tree[@root] = []
            v= []
            bleh = []
            @root.servers.each do |x|
                bleh.push([x])
            end
            bleh.sort(&@sort).each do |x|
                x = x[0]
                v += (x.channels+x.chats)
            end

            tree[@root] = sort_with_predefined(v)
            
            tree[@root].each {|c, o| @numbers.push(c) if o == 0}
            return tree
        elsif @networks
            @numbers = []
            tree = OrderedHash.new
            tree[@root] = OrderedHash.new
            bleh = []
            @root.servers.each do |x|
                bleh.push([x])
            end
            bleh.sort(&@sort).each do |x|
                x = x[0]
                tree[@root][x] = sort_with_predefined(x.channels+x.chats)
                
                tree[@root][x].each {|c, b| @numbers.push(c)}
            end
            return tree
        else
            puts 'invalid structure algorithim'
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
        if !@networks
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
        elsif @networks
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
                (item.channels+item.chats).each {|e| add(e, true)}
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
                        y.each_with_index do |z, i|
                            if z[0] == item
                                if i > 0
                                    @numbers.insert(tab2number(y.keys[i-1]), item)
                                else
                                    if y.length == 1
                                        if prev_server(s)
                                            v = @tree[@root][prev_server(s)]
                                            num = tab2number(v[-1])
                                        else
                                            num = 0
                                        end
                                        @numbers.insert(num, item)
                                    else
                                        @numbers.insert(tab2number(l[0])-1, item)
                                    end
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
        changed
        puts 'forwarding status change for '+item.name+' to '+level.to_s
        notify_observers(:setstatus, item, level)
    end
    
    def set_active(item)
        changed
        notify_observers(:set_active, item)
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
        if !@networks
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
        elsif @networks
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
        return result ||= -1
    end
    
    def draw_tree
        puts @root.name
        @tree[@root].each do |a, b|
            puts "\t"+a.name if @networks
            if b.methods.include?('each')
                b.each do |c, d|
                    next if c == 0
                    puts "\t\t"+tab2number(c).to_s+':'+c.name
                end
            else
                puts "\t"+tab2number(a).to_s+':'+a.name unless @networks
            end
        end
    end
end

class TabList
    attr_reader :model
    def initialize(model)
        @model = model
        @status = {}
        @active = nil
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
        end
    end
    
    def setstatus(buffer, status)
        return unless buffer
		if !@status[buffer] or status > @status[buffer] or status == 0
            puts 'setting status of '+buffer.name+' to '+status.to_s
			@status[buffer] = status
			recolor(buffer)
        else
            puts 'not setting status of '+buffer.name+' to '+status.to_s
            puts status, @status[buffer]
        end
	end
end
    

class BoxTabList < TabList
    def initialize(model)
        super
        @buttons = {}
        @togglehandlers = {}
        fill_box
        @box.show_all
        
        set_active(model.root)
    end
    
    def widget
        return @box
    end
    
    def fill_box
        @box.pack_start(add_button(@model.root), false, false)
        add_seperator
        b = nil
        @model.tree[@model.root].each do |k, v|
            @box.pack_start(add_button(k), false, false)
            if v.methods.include?('each')
                v.each do |z, c|
                    @box.pack_start(add_button(z), false, false)
                end
                add_seperator
            else
            
            end
        end
        cleanup
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
        puts x.length
        puts @box.children.length
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
                puts prev, x[i]
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
        @box.show_all
    end
        
    def remove(tab)
    
        if @buttons[tab]
            @box.remove(@buttons[tab])
            @buttons.delete(tab)
        end
        
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
        @box.show_all
    end
    
    def set_active(buffer)
        if @active
            @buttons[@active].signal_handler_block(@togglehandlers[@active])
            @buttons[@active].active = false
            @buttons[@active].signal_handler_unblock(@togglehandlers[@active])
            oldactive = @active
        end
        setstatus(@active, ACTIVE)
        @active = buffer
        setstatus(oldactive, INACTIVE) if oldactive
        
        @buttons[@active].signal_handler_block(@togglehandlers[@active])
        @buttons[@active].active = true
        @buttons[@active].signal_handler_unblock(@togglehandlers[@active])
        $main.window.switchchannel(buffer) if $main.window
    end
    
	def recolor(buffer)
        return if buffer == @active
		label = @buttons[buffer].child
		label.modify_fg(Gtk::STATE_NORMAL, $config.getstatuscolor(@status[buffer]))
        label.modify_fg(Gtk::STATE_PRELIGHT, $config.getstatuscolor(@status[buffer]))
        
	end
    
    def add_button(buffer)
        if !@buttons.include?(buffer)
            button = Gtk::ToggleButton.new(buffer.name)
            @togglehandlers[buffer] = button.signal_connect('toggled')do |w|
                set_active(buffer)
            end
            @buttons[buffer] = button
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
        return b
    end
    
    def add_seperator
        b = Gtk::HSeparator.new
        @box.pack_start(b, false, false, 5)
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
        return b
    end
    
    def add_seperator
        b = Gtk::VSeparator.new
        @box.pack_start(b, false, false, 5)
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
            set_active(iter2buffer(w.selected))
        end
        @iters = {}
        fill_list
        renderer = Gtk::CellRendererText.new
		
		col = Gtk::TreeViewColumn.new("", renderer, :markup => 0)
		@view.append_column(col)
		@view.expand_all
        @view.show_all
        set_active(model.root)
    end
    
    def widget
        return @view
    end
    
    def fill_list
        parent = @store.append(nil)
        parent[0] = @model.root.name
        @iters[@model.root] = Gtk::TreeRowReference.new(@store, parent.path)
        @model.tree[@model.root].each do |k, v|
            child = @store.append(parent)
            child[0] = k.name
            @iters[k] = Gtk::TreeRowReference.new(@store, child.path)
            @view.expand_row(parent.path, false)
            if v.methods.include?('each')
                v.each do |z, c|
                    child2 = @store.append(child)
                    child2[0] = z.name
                    @iters[z] = Gtk::TreeRowReference.new(@store, child2.path)
                    @view.expand_row(child.path, false)
                end
            else
            
            end
        end
        cleanup
    end
    
    def add(item)
        i = 0
        @model.tree[@model.root].each do |k, v|
            path = '0:'+i.to_s
            this = @store.get_iter(path)
            if this and this[0] != k.name
                new = @store.insert_before(@store.get_iter(@iters[@model.root].path), this)
                new[0] = k.name
                @iters[k] = Gtk::TreeRowReference.new(@store, new.path)
                @view.expand_row(@iters[@model.root].path, false)
            elsif !this
                new = @store.insert_before(@store.get_iter(@iters[@model.root].path), nil)
                new[0] = k.name
                @iters[k] = Gtk::TreeRowReference.new(@store, new.path)
                @view.expand_row(@iters[@model.root].path, false)
            end
            j = 0
            if v.methods.include?('each')
                v.each do |z, c|
                    path2 = '0:'+i.to_s+':'+j.to_s
                    this2 = @store.get_iter(path2)
                    if this2 and this2[0] != z.name
                        puts path2, z.name
                        new = @store.insert_before(@store.get_iter(@iters[k].path), this2)
                        new[0] = z.name
                        @iters[z] = Gtk::TreeRowReference.new(@store, new.path)
                        @view.expand_row(this.path, false)
                    elsif !this2
                        path2 = '0:'+i.to_s+':'+(j-1).to_s
                        new = @store.insert_before(@store.get_iter(@iters[k].path), nil)
                        new[0] = z.name
                        @iters[z] = Gtk::TreeRowReference.new(@store, new.path)
                        @view.expand_row(this.path, false)
                    end
                    j += 1
                end
            end
            i += 1
        end
        cleanup
    end
    
    #ack, I wish I didn't need this
    def cleanup
        @store.each do |model, path, iter|
            if !iter2buffer(iter)
                puts iter
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
    
    def clean_tag(tag)
        re = /^\<span .+\>(.+?)\<\/span\>$/i
        md = re.match(tag)
        if md
            return md[1]
        else
            return tag
        end
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
        return if buffer == @active
        if @iters[buffer]
            iter = @store.get_iter(@iters[buffer].path)
            if @status[buffer] > 0
                color = $config.getstatuscolor(@status[buffer]).to_hex
                iter[0] = '<span color="'+color+'">'+clean_tag(iter[0])+'</span>'
                puts 'recoloring '+buffer.name
            else
                iter[0] = clean_tag(iter[0])
                puts 'not recoloring active buffer '+buffer.name
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