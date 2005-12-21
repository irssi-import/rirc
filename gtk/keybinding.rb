#~ require 'libglade2'
#~ Gtk.init

module KeyBind
    def event_to_string(event)
        mods = []
        
        if (event.state & Gdk::Window::MOD1_MASK) != 0
            mods.push('Alt')
        end
        if (event.state & Gdk::Window::CONTROL_MASK) != 0
            mods.push('Ctrl')
        end
        if (event.state & Gdk::Window::SHIFT_MASK) != 0
            mods.push('Shift')
        end
        
        return false if mods.empty?
        
        key = Gdk::Keyval.to_name(event.keyval)
        
        x = (mods.push(key)).join('-')
        
        return x
    end
end

class KeyBindingWindow < SingleWindow
    include KeyBind
    attr_accessor :sizegroups
    def initialize(bindings, methods)
        @glade = GladeXML.new("glade/keybindings.glade") {|handler| method(handler)}
        @grabkeys = false
        @keybox = @glade['keybox']
        @tooltips = Gtk::Tooltips.new
        @meths = methods
        @rows = []
        @sizegroups = []
        5.times do
            @sizegroups.push(Gtk::SizeGroup.new(Gtk::SizeGroup::HORIZONTAL))
        end
        
        @fakerow = FakeKeyBindingRow.new(self, @meths)
        
        @title = Gtk::HBox.new
        
        ['', 'Key Combo', 'Action', 'Arguments'].each_with_index do |x, i|
            w = Gtk::Label.new(x)
            @title.add(w)
            @sizegroups[i].add_widget(w)
        end
        
        @keybox.pack_start(@title, false, false)
        @keybox.pack_start(@fakerow, false, false, 2)
        
        load_bindings(bindings)
        
        @open = true
        
        @glade['keywindow'].signal_connect('key_release_event') { |widget, event| window_buttons(widget, event)}
        
        @glade['keywindow'].show_all
    end
    
    def action2index(action)
        x = 0
        @meths.each_with_index do |m, i|
            if m['name'] == action
                x = i+1
            end
        end
        
        return x
    end
    
    def load_bindings(bindings)
        bindings.each do |k, v|
            puts k, v unless v and k
            next unless v and k
            command, args = v.split('(', 2)
            args.chomp!(')') if args
            x = KeyBindingRow.new(self, @meths)
            x.set_binding(k)
            y = action2index(command)
            next unless y > 0
            x.set_action(y)
            x.set_arguments(args) if args
            @rows.push(x)
        end
        
        #do a sort here, probably by action name
        @rows.sort!{|x, y| x.get_action <=> y.get_action}
        @rows.sort!{|x, y| x.get_arguments <=> y.get_arguments}
        @rows.each_with_index do |row, i|
            @keybox.pack_start(row, false, false, 2)
            @keybox.reorder_child(row, i+1)
            row.show_all
        end
    end
    
    def save_bindings
        result = {}
        @rows.each do |row|
            if row.get_binding != '' and row.get_action != ''
                result[row.get_binding] = "#{row.get_action}(#{row.get_arguments})".chomp('()')
            end
        end
        
        #~ result.each do |k, v|
            #~ puts k+' => '+v
        #~ end
        return result
    end
    
    def grab_keys(listener)
        @rows.each do |row|
            if row != listener
                row.inactivate
            end
        end
        
        if listener != @fakerow
            @fakerow.inactivate
        end
        
        listener.partially_inactivate
        
        if @grabkeys
            if listener != @listener
                listener.ignore_binding_request
                return
            else
                @rows.each {|row| row.activate}
                @fakerow.activate
                @listener.set_binding('')
                return
            end
        end
        @grabkeys = true
        @listener = listener
    end
    
    def add_row
        x = KeyBindingRow.new(self, @meths)
        @rows.push(x)
        @keybox.pack_start(x, false, false, 2)
        @keybox.reorder_child(x, @rows.length)
        x.show_all
        return x
    end
    
    def remove_row(row)
        @rows.delete(row)
        @keybox.remove(row)
    end
    
    def window_buttons(widget, event)
        return unless @grabkeys
        x = event_to_string(event)
        if x
            @grabkeys = false
            @rows.each {|row| row.activate}
            @fakerow.activate
            dup = false
            @rows.each do |row|
                if row != @listener and row.get_binding == x
                    dup = true
                end
            end
            if dup
                @listener.set_binding(nil)
            else
                @listener.set_binding(x)
            end
        end
    end
    
    def set_tooltip(widget, tip)
        @tooltips.set_tip(widget, tip, '')
    end
    
    def ok_clicked
        $config.set_value('keybindings', save_bindings)
        destroy
    end
    
    def destroy
        @open = false
        @glade['keywindow'].destroy
    end
    
end

class KeyBindingRow < Gtk::HBox
    def initialize(window, commands)
        super()
        spacing = 2
        @window = window
        homogenous = true
        @bindbutton = Gtk::ToggleButton.new('Set Keybinding')
        @sig = @bindbutton.signal_connect('pressed') {|| @window.grab_keys(self)}
        @keybind = Gtk::Label.new
        @actioncombo = Gtk::ComboBox.new
        @actioncombo.signal_connect('changed') {|| action_changed}
        @commands = commands
        @arguments = Gtk::Entry.new
        @arguments.sensitive = false
        @arguments.width_chars = 10
        @handlers = {}
        [@bindbutton, @keybind, @actioncombo, @arguments].each_with_index do |w, i|
            pack_start(w, true, false)
            @window.sizegroups[i].add_widget(w)
        end
        fill_combos
    end
    
    def inactivate
        @bindbutton.sensitive = false
        @actioncombo.sensitive = false
    end
    
    def partially_inactivate
        @actioncombo.sensitive = false
    end
    
    def activate
        @bindbutton.sensitive = true
        @actioncombo.sensitive = true
    end
    
    def set_binding(binding)
        if binding
            @binding = binding
            @keybind.text = binding
            @bindbutton.active = false
            check_row
        else
            @bindbutton.active = false
        end
    end
    
    def get_binding
        return @keybind.text
    end
    
    def ignore_binding_request
        @bindbutton.toggled
    end
    
    def fill_combos
        @actioncombo.append_text('')
        @commands.each do |cmd|
            @actioncombo.append_text(cmd['name'])
        end
    end
    
    def action_changed
        if @actioncombo.active != -1
            selection = @actioncombo.active_iter[0]
            @commands.each do |cmd|
                if cmd['name'] == selection
                    args = cmd['arguments']
                    if args == 0
                        @arguments.text = ''
                        @arguments.sensitive = false
                        tip = 'No Arguments'
                    else
                        @arguments.sensitive = true
                        if args > 0
                            tip = args.to_s+' required arguments'
                        elsif args < -1
                            tip = ((args*-1)+1).to_s+' required arguments, additional optional arguments'
                        elsif args == -1
                            tip = 'Optional arguments'
                        end
                    end
                    @window.set_tooltip(@arguments, tip)
                elsif selection == ''
                    @arguments.sensitive = false
                    @window.set_tooltip(@arguments, '')
                end
            end
            check_row
        end
    end
    
    def get_action
        return @actioncombo.active_iter[0]
    end
    
    def set_action(index)
        @actioncombo.active=index
    end
    
    def set_arguments(args)
        @arguments.text = args if @arguments.sensitive?
    end
    
    def get_arguments
        @arguments.text
    end
    
    def check_row
        if @keybind.text == '' and @actioncombo.active <= 0
            puts 'empty row'
            @window.remove_row(self)
        end
    end
end

class FakeKeyBindingRow < KeyBindingRow
    def initialize(window, commands)
        super
        @bindbutton.label ='Add Keybinding'
    end
    
    def set_binding(binding)
        @bindbutton.active = false
        return if binding == '' or binding == nil
        row = @window.add_row
        row.set_binding(binding)
    end
    
    def action_changed
        if @actioncombo.active > 0
            row = @window.add_row
            row.set_action(@actioncombo.active)
            @actioncombo.active = -1
        end
    end
end
#~ b = []
#~ b.push({'name' => 'switchtab', 'arguments' => 1})
#~ b.push({'name' => 'open_linkwindow', 'arguments' => 0})

#~ @values = {}

#~ @values['keybindings'] = {}

#~ @values['keybindings']['Alt-l'] = 'open_linkwindow'

#~ 9.times do |i|
    #~ @values['keybindings']['Alt-'+i.to_s] = 'switchtab('+i.to_s+')'
#~ end

#~ j = 10
#~ %w{0 q w e r t y u i o p}.each do |c|
    #~ @values['keybindings']['Alt-'+c] = 'switchtab('+j.to_s+')'
    #~ j += 1
#~ end

#~ KeyBindingWindow.new(@values['keybindings'], b)
#~ Gtk.main