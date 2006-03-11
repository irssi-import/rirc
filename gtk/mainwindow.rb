
class MainWindow
    attr_reader :currentbuffer, :buffers, :main, :config
    include KeyBind
    def initialize(main, confighash)
        @main = main
        @confighash = confighash
        @config = @main.config

        #try to setup the Gtk::Entry to not select-on-focus
#         Gtk::RC.parse_string("style \"message_input\" {\
#                              gtk-select-on-focus=0}")

        @glade = GladeXML.new("gtk/glade/mainwindow.glade") {|handler| method(handler)}

        @usernamebutton = @glade["username"]
        @topic = @glade["topic"]
        @messageinput = @glade["message_input"]
        @messagescroll = @glade['message_scroll']
        @messagevadjustment = @messagescroll.vadjustment

        @tooltips = Gtk::Tooltips.new

        @messageinput.grab_focus
        @messageinput.signal_connect("key_press_event"){|widget, event| input_buttons(widget, event)}
        @messageinput.buffer.signal_connect_after("changed"){|widget| @currentbuffer.buffer.view.scroll_to_end if @currentbuffer and widget.text.include? "\n"}

        @userlist = @glade['userlist']
        @panel = @glade['hpaned1']
        @vpanel = @glade['vpaned1']
        @vpanel.hide
        @mainbox = @glade['mainbox']
        @messagebox = @glade['vbox2']
        @preferencesbar = @glade['preferencesbar']
        @usercount = @glade['usercount']
        @currentbuffer = @serverlist

        @glade['window1'].default_width = @confighash['width']
        @glade['window1'].default_height = @confighash['height']

        @usernamebutton.hide
        @topic.hide

        @messagescroll.set_size_request(0, -1)#magical diamond skill 7 hack to stop window resizing
        args = [self]
        if @confighash['console']
            args.push(@main.console)
        end
        @buffers = BufferListController.new(*args)
        redraw_channellist(true)

        #n = @buffers.add_network('Vagabond', 'TestNode')
        #@buffers.connect(n)

        #n = @buffers.add_network('Freenode', 'Foo')
        #@buffers.connect(n)

        #Gtk::Window.new.add(@buffers.view.widget).show_all
        #switch_buffer(@buffers.active.buffer.view)

        @glade['window1'].signal_connect('key_press_event') { |widget, event| window_buttons(widget, event)}

        @me = self

        @last = nil

        @highlighted = []

        @linkcursor = Gdk::Cursor.new(Gdk::Cursor::HAND2)
        @normalcursor = Gdk::Cursor.new(Gdk::Cursor::LEFT_PTR)

        @defaultmenu = Gtk::Menu.new
        @defaultmenu.append(Gtk::MenuItem.new("thing1"))
        @defaultmenu.append(Gtk::MenuItem.new("thing2"))

        @bindable_functions = []
        @bindable_functions.push({'name' => 'switchtab', 'arguments' => 1})
        @bindable_functions.push({'name' => 'open_linkwindow', 'arguments' => 0})
        @bindable_functions.push({'name' => 'open_preferences', 'arguments' => 0})
        @bindable_functions.push({'name' => 'open_networks', 'arguments' => 0})
        @bindable_functions.push({'name' => 'open_keybindings', 'arguments' => 0})
        @bindable_functions.push({'name' => 'next_buffer', 'arguments' => 0})
        @bindable_functions.push({'name' => 'prev_buffer', 'arguments' => 0})
        #@keyintmap = {'q' => 11, 'w' => 12, 'e' => 13, 'r' => 14, 't'=> 15, 'y' => 16, 'u' => 17, 'i' => 18, 'o' => 19, 'p' => 20}
    end

    def draw_from_config(unhide=true)
        puts 'drawing from config'
        #~ return if $main.quitting
        #~ #@serverlist.redraw
        #~ redraw_channellist
        #~ #resize the window if we have some saved sizes...
        #~ x = -1
        #~ y = -1

        #~ x = $config['windowwidth'].to_i if $config['windowwidth']
        #~ y = $config['windowheight'].to_i if $config['windowheight']

        #~ @glade['window1'].default_width = x
        #~ @glade['window1'].default_height = y
        #~ @glade['window1'].resize(x, y)

        #~ @panel.position = $config['panelposition'].to_i if $config['panelposition']

        @font = Pango::FontDescription.new(@config['main_font'])

        #~ update_view(@serverlist.view.view)
        #~ @serverlist.servers.each do |server|
        #~ update_view(server.view.view)
        #~ server.channels.each {|channel| update_view(channel.view.view)}
        #~ server.chats.each {|chat| update_view(chat.view.view)}
        #~ end

        #TODO - figure out how to set the cursor-color style var (its undocumented, might not be in ruby-gtk2)
        #maybe use parse_string like for scwview
        #@glade['window1'].resize(@confighash['width'], @confighash['height'])
        @glade['window1'].move(@confighash['xpos'], @confighash['ypos'])
        redraw_channellist
        @glade['window1'].show_all
        @glade['window1'].move(@confighash['xpos'], @confighash['ypos'])
        @panel.position = @confighash['panelposition']
        #@glade['window1'].resize(@confighash['width'], @confighash['height'])
        @topic.hide unless @currentbuffer.respond_to? :topic
        @usernamebutton.hide unless @currentbuffer.respond_to? :username
        @messageinput.grab_focus
    end

    def redraw_channellist(force=false)
        oldview = @buffers.view
        @buffers.recreate
        puts "switch channellist? #{oldview != @buffers.view} #{oldview} #{@buffers.view}"
        if oldview != @buffers.view or force
            @buffers.view.widget.show_all

            if @config['tablisttype'] == 'button'
                @vpanel.remove(@vpanel.child2)
                @glade['v_top'].pack_start(@buffers.view.widget, false, false, 5)
            elsif @config['tablisttype'] == 'treeview'
                @glade['v_top'].remove(oldview.widget)
                @vpanel.pack2(@buffers.view.widget, false, true)
            end
        end

#         return

#         if @buffers
#             if @glade['h_top'].children.include?(@buffers.view.widget)
#                 @glade['h_top'].remove(@buffers.view.widget)
#             elsif @glade['v_top'].children.include?(@buffers.view.widget)
#                 @glade['v_top'].remove(@buffers.view.widget)
#             elsif @glade['u_pane'].children.include?(@buffers.view.widget)
#                 @glade['u_pane'].remove(@buffers.view.widget)
#             end
#         end

#         if $config['tablisttype'] == 'treeview'
#             if $config['tablistposition'] != 'right' and $config['tablistposition'] != 'left' and $config['tablistposition'] != 'underuserlist'
#                 $config['tablistposition'] = 'left'
#             end
#             unless @tablist.class == TreeTabList
#                 $main.tabmodel.delete_observer(@tablist)
#                 @tablist = TreeTabList.new($main.tabmodel)
#             end
#         else
#             if $config['tablistposition'] == 'right' or $config['tablistposition'] == 'left' or $config['tablistposition'] == 'underuserlist'
#                 unless @tablist.class == VBoxTabList
#                     $main.tabmodel.delete_observer(@tablist)
#                     @tablist = VBoxTabList.new($main.tabmodel)
#                 end
#             else
#                 unless @tablist.class == HBoxTabList
#                     $main.tabmodel.delete_observer(@tablist)
#                     @tablist = HBoxTabList.new($main.tabmodel)
#                 end
#             end
#         end

#         $main.tabmodel.set_sort_and_structure(*$config.gettabmodelconfig)
#         @tablist.renumber

#         if $config['tablistposition'] == 'right'
#             @glade['h_top'].pack_start(@tablist.widget, false, false, 5)
#         elsif $config['tablistposition'] == 'left'
#             @glade['h_top'].pack_start(@tablist.widget, false, false, 5)
#             @glade['h_top'].reorder_child(@tablist.widget, 0)
#         elsif $config['tablistposition'] == 'top'
#             @glade['v_top'].pack_start(@tablist.widget, false, false, 5)
#             @glade['v_top'].reorder_child(@tablist.widget, 0)
#         elsif $config['tablistposition'] == 'bottom'
#             @glade['v_top'].pack_start(@tablist.widget, false, false, 5)
#         elsif $config['tablistposition'] == 'underuserlist'
#             @glade['u_pane'].pack2(@tablist.widget, false, true)
#         end
        #@tablist.widget.show_all
    end

    def prev_buffer
        @buffers.prev_buffer
    end

    def next_buffer
        @buffers.next_buffer
    end

    def set_username
        x = nil
        label = Gtk::Label.new("New username")
        entry = Gtk::Entry.new
        entry.text = @currentbuffer.network.username
        dialog = Gtk::Dialog.new("Username", nil,
                                 Gtk::Dialog::MODAL | Gtk::Dialog::DESTROY_WITH_PARENT,
                                 [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                                 [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])
        dialog.vbox.add(label)
        dialog.vbox.add(entry)
        dialog.show_all
        dialog.run do |response|
            case response
            when Gtk::Dialog::RESPONSE_ACCEPT
                x = entry.text
            end
            dialog.destroy
        end
        @main.send_command('nick'+x, "presence change;#{@currentbuffer.network.identifier_string};name=#{x}") if x
    end

    def topic_change(widget)
        if widget.text != @currentbuffer.topic and @currentbuffer.class == ChannelBuffer
            @main.send_command('topicchange', 'channel change;network='+@currentbuffer.network.name+';mypresence='+@currentbuffer.presence+';channel='+@currentbuffer.name+';topic='+escape(widget.text))
        end
        #add_message("Topic changed to: "+ widget.text, 'notice')
    end

    #get the substring to use for tab completion.
    def get_completion_substr
#         string = @messageinput.buffer.text
#         position = @messageinput.position
#         string = string[0, position]
        buffer = @messageinput.buffer

        #get the string between the beginning of the buffer and the cursor position
        string = buffer.get_text(buffer.start_iter, buffer.get_iter_at_mark(buffer.get_mark("insert")))
        #get the string between the end of the string and the last space (the fragment we use for matching)
        name, whatever = string.reverse.split(' ', 2)

        return nil unless name

        name = name.reverse

        return name
    end

    #function to do the nick replace for tab completion
    def replace_completion_substr(substr, match)
        string = @messageinput.buffer.text
#         position = @messageinput.position

        buffer = @messageinput.buffer
        insertmark = buffer.get_mark("insert")
        #create a mark at the cursor location with right gravity (so it moves right when we insert text behind it)
        mark = buffer.create_mark(nil, buffer.get_iter_at_mark(insertmark), false)
        
        #split the string by the cursor position
#         a = string[0, position]
#         b = string[position, string.length-position]

        #use rstrip to ignore traling whitespace for calculating the start of the nick
#         nickstart = a.rstrip.length-substr.length
        #nick replace
#         a = a.reverse.sub(substr.reverse, match.reverse)
#         a.reverse!
        #reassemble the string, converting the pieces to strings if they're nulls
#         a ||= ''
#         b ||= ''
#         string = a+b
        
        #create a new position, move it backwards by the length of the substr and use it to set the position of the insert mark
        newpos = buffer.get_iter_at_mark(insertmark)
        
        #get the index of the beginning of the substring
        index = string.rindex(substr, newpos.offset)
        #move the cursor to the index
        newpos.offset = index
        buffer.move_mark(insertmark, newpos)

        #because we only moved the insert mark, we should have some text selected
        buffer.delete_selection(false, true)
        
        insertiter = buffer.get_iter_at_mark(insertmark)
#         nextchar =
        
#         cursorposition = match.length
        #determine current position and take action
        if insertiter == buffer.start_iter
            #the beginning
            if match[0].chr == '/'
                unless insertiter.char == ' '
#                     string.insert(match.length, ' ')
                    replacement = match+' '
#                     cursorposition = match.length+1
                end
            elsif insertiter.char == ' '
#                 string.insert(match.length, @config['tabcompletesuffix'])
#                 cursorposition = match.length+1
                replacement = match+@config['tabcompletesuffix']
            else
#                 string.insert(match.length, @config['tabcompletesuffix']+' ')
#                 cursorposition = match.length+2
                replacement = match+@config['tabcompletesuffix']+' '
            end
        elsif insertiter == buffer.end_iter
            #we're at the end
#             string += ' '
#             cursorposition += 1
            replacement = match+' '
        else
            #somewhere in the middle
            if insertiter.char != ' '
#                 string.insert(nickstart+match.length, ' ')
#                 cursorposition = match.length+1
                replacement = match+' '
            else
#                 cursorposition = match.length+1
                replacement = match
            end
        end
        #update the content of the entry
        buffer.insert_at_cursor(replacement)
        buffer.place_cursor(buffer.get_iter_at_mark(mark))
#         @messageinput.buffer.text = string
        #reposition the cursor
#         @messageinput.set_position(nickstart+cursorposition)
    end

    def switch_buffer(obj)
        update_dimensions
#         puts obj
        @messagescroll.remove(@messagescroll.child) if @messagescroll.child
        @vpanel.remove(@vpanel.child1) if @vpanel.child1
        @commandbuffer.currentcommand = @messageinput.buffer.text if @commandbuffer
        @currentbuffer.buffer.marklastread if @currentbuffer and @currentbuffer.buffer
        @currentbuffer = obj
        @commandbuffer = @currentbuffer.commandbuffer
        @messageinput.buffer.text = @commandbuffer.currentcommand
        #         puts "commandbuffer: #{@commandbuffer}"
        
        #puts "switching view to #{obj.buffer.view}"
        if @currentbuffer.respond_to? :username
            @usernamebutton.label = @currentbuffer.username.gsub('_', '__')
            @usernamebutton.show
        else
            @usernamebutton.hide
        end
        if @currentbuffer.respond_to? :topic
            update_topic
            @topic.show
        else
            @topic.hide
        end

        if @currentbuffer.respond_to? :userlistview
            @vpanel.show_all
            @currentbuffer.userlistview.widget.show_all
            @vpanel.pack1(@currentbuffer.userlistview.widget, false, false)
#             puts @panel.position, @confighash['panelposition'], @confighash['panelposition'].class
#             puts 'setting panel position'
            @panel.position = @confighash['panelposition'].to_i
#             puts @panel.position
            #puts "userlist: #{@currentbuffer.userlistview}"
        elsif @config['tablisttype'] == 'treeview'
            @panel.position = @confighash['panelposition'].to_i
            @vpanel.remove(@vpanel.child1)
        else
            @vpanel.hide
        end

        @messagescroll.child = @currentbuffer.buffer.view
        @currentbuffer.buffer.view.show 
        @currentbuffer.buffer.view.scroll_to_end
        set_title
        @messageinput.grab_focus
    end

    def set_title
        if @currentbuffer.respond_to? :network and @currentbuffer.network != @currentbuffer
            if @currentbuffer.kind_of? ChatBuffer
                @glade['window1'].title= "Query with #{@currentbuffer.name} on #{@currentbuffer.network.name} - Ratchet"
            else
                @glade['window1'].title= "#{@currentbuffer.name} on #{@currentbuffer.network.name} - Ratchet"
            end
        else
            @glade['window1'].title = "#{@currentbuffer.name} - Ratchet"
        end
    end

    #~ def switchchannel(channel)
    #~ #make the new channel the current one, and toggle the buttons accordingly
    #~ return unless channel
    #~ #update_dimensions

    #~ @currentbuffer.currentcommand = @messageinput.text
    #~ if @currentbuffer.class == ChannelBuffer
    #~ @userlist.remove_column(@currentbuffer.modecolumn)
    #~ @userlist.remove_column(@currentbuffer.usercolumn)
    #~ end
    #~ @currentbuffer = channel
    #~ drawuserlist(@currentbuffer.class == ChannelBuffer)
    #~ @messageinput.text = @currentbuffer.currentcommand
    #~ @messageinput.select_region(0, 0)
    #~ @messageinput.position=-1
    #~ @messagescroll.children.each {|child| @messagescroll.remove(child)}
    #~ @messagescroll.add(@currentbuffer.view.view)
    #~ @messagescroll.show_all

    #~ @messagescroll.set_size_request(0, -1)#magical diamond skill 7 hack to stop window resizing
    #~ @usernamebutton.label = @currentbuffer.username.gsub('_', '__') if @currentbuffer.username
    #~ @currentbuffer.view.view.scroll_to_end
    #~ @messageinput.grab_focus
    #~ end

    #~ def updateusercount
    #~ return unless @currentbuffer.class == ChannelBuffer
    #~ modes = {}
    #~ modeorder = []
    #~ @currentbuffer.users.users.each do |user|
    #~ mode = user.get_mode
    #~ if modes[mode]
    #~ modes[mode] += 1
    #~ elsif mode != ''
    #~ modes[mode] = 1
    #~ modeorder[user.decodemode(mode)] = mode
    #~ end
    #~ end

    #~ modeorder.reverse!
    #~ text = ''
    #~ modeorder.each do |m|
    #~ next if m == nil
    #~ text +=modes[m].to_s+m+', '
    #~ end

    #~ text += @currentbuffer.users.users.length.to_s+' total'
    #~ @usercount.text = text
    #~ end

    #~ def drawuserlist(toggle)
    #~ if toggle
    #~ @mainbox.remove(@messagebox)
    #~ @mainbox.pack_start(@panel)
    #~ @panel.add1(@messagebox)
    #~ @messageinput.grab_focus
    #~ @userlist.model = @currentbuffer.userlist
    #~ @userlist.append_column(@currentbuffer.modecolumn)
    #~ @userlist.append_column(@currentbuffer.usercolumn)
    #~ @userlist.search_column=1
    #~ @userlist.show_all
    #~ @topic.show
    #~ @topic.text =@currentbuffer.topic
    #~ @tooltips.set_tip(@topic, @currentbuffer.topic, '')
    #~ @usernamebutton.show
    #~ updateusercount
    #~ else
    #~ @mainbox.remove(@panel)
    #~ @panel.remove(@messagebox)
    #~ @mainbox.pack_start(@messagebox)
    #~ @messageinput.grab_focus
    #~ @topic.hide
    #~ @topic.text = ''
    #~ if @currentbuffer.class == Console
    #~ @usernamebutton.hide
    #~ else
    #~ @usernamebutton.show
    #~ end
    #~ end
    #~ end

    def message_input
        return if @messageinput.buffer.text.length == 0
        @commandbuffer.add_command(@messageinput.buffer.text)

        if @currentbuffer.respond_to? 'parent'
            network = @currentbuffer.parent
            presence = @currentbuffer.parent.presence
        elsif @currentbuffer.respond_to? 'presence'
            network = @currentbuffer
            presence = @currentbuffer.presence
        else

        end

        message = @messageinput.buffer.text.dup
        @main.queue_input([message, @currentbuffer])
        
#         @messageinput.buffer.place_cursor(@messageinput.buffer.start_iter)
        @messageinput.buffer.text = ''
#         @messageinput.buffer.delete(*@messageinput.buffer.bounds)
#         @messageinput.select_all(true)
#         @messageinput.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, -3, false)
    end

    def message_input_focus
        true
    end

    def get_username
        @usernamebutton.label = @currentbuffer.username.gsub('_', '__')
    end

    def show_username
        @usernamebutton.show
    end

    def update_dimensions
#         puts 'updating dimensions'
        width, height = @glade['window1'].size
        xpos, ypos = @glade['window1'].position
        @confighash['panelposition'] = @panel.position if @panel.child2.visible?
        @confighash['width']=  width if width
        @confighash['height'] = height if height
        @confighash['xpos'] = xpos if xpos
        @confighash['ypos'] = ypos if ypos
    end

    def update_topic
        @topic.text = @currentbuffer.topic
        @tooltips.set_tip(@topic, @currentbuffer.topic, '')
    end



    #~ def create_link_popup(link)
    #~ menu = Gtk::Menu.new
    #~ link = to_uri(link)
    #~ item = Gtk::MenuItem.new(link)
    #~ item.sensitive = false
    #~ menu.append(item)
    #~ menu.append(Gtk::MenuItem.new("Open link in browser"))
    #~ menu.append(Gtk::MenuItem.new("Copy link location"))
    #~ end


    def whois(user)
        return unless @currentbuffer.respond_to? :users
        @main.send_command('whois'+user, "presence status;#{@currentbuffer.network.identifier_string};presence=#{user}")
    end

    def commandbuffer
        @commandbuffer
    end

    def input_buttons(widget, event)
        return unless event.class == Gdk::EventKey #ack, another guard against non EventKey events
        if event.keyval == Gdk::Keyval.from_name('Tab')
            #if @currentbuffer.class == ChannelBuffer || @currentbuffer.class == ChatBuffer
            substr = get_completion_substr
            nick = @currentbuffer.tabcomplete(substr) if substr
            replace_completion_substr(substr, nick) if nick
            return true #block the signal
            #end
        else
            #if @currentbuffer.class == ChannelBuffer || @currentbuffer.class == ChatBuffer
            @currentbuffer.clear_tabcomplete
            #end
        end
        
        #A return key is pressed, check to see if shift is pressed too...
        if event.keyval == Gdk::Keyval.from_name('Return') and (event.state & Gdk::Window::SHIFT_MASK) == 0
            #shift ain't pressed
            message_input #handle the input
            return true #block the signal
#         elsif event.keyval == Gdk::Keyval.from_name('Return')
            #shift was pressed
#             @messageinput.buffer.insert_at_cursor("\n") #stick a newline in
#             @currentbuffer.buffer.view.scroll_to_end #scroll the scwview to end
#             return true #block the signal
        end

        if event.keyval == Gdk::Keyval.from_name('Up')
            @messageinput.buffer.text = commandbuffer.last_command if commandbuffer
        elsif event.keyval == Gdk::Keyval.from_name('Down')
            @messageinput.buffer.text = commandbuffer.next_command if commandbuffer
        end
        false
    end

    def window_buttons(widget, event)
        return unless event.class == Gdk::EventKey #make sure we're only dealing with EventKeys
        x = event_to_string(event)
        unless x
            key = Gdk::Keyval.to_name(event.keyval)
            if key == "Page_Up"
                scroll_up
            elsif key == "Page_Down"
                scroll_down
            end
        end
        return unless x and @config['keybindings'][x]
        command, args = @config['keybindings'][x].split('(', 2)
        args ||= ''
        args.chomp!(')')
        args = args.split(',').map{|e| e.downcase}
        if command and self.respond_to?(command)
            self.send(command, *args)
            return true #block any futher things
        else
            return false
        end
        #eval($config['keybindings'][x])
        #~ if (event.state & Gdk::Window::MOD1_MASK) != 0
        #~ puts 'pressed alt-'+Gdk::Keyval.to_name(event.keyval) if $args['debug']
        #~ key = Gdk::Keyval.to_name(event.keyval)
        #~ if key =~ /\d/
        #~ key = 10 if key.to_i == 0
        #~ tab = @serverlist.number2tab(key.to_i)
        #~ switchchannel(tab)
        #~ return true
        #~ elsif key =~ /[qwertyuiop]+/
        #~ tab = @serverlist.number2tab(@keyintmap[key].to_i)
        #~ switchchannel(tab)
        #~ return true
        #~ elsif key == 'l'
        #~ LinkWindow.new(@currentbuffer.links)
        #~ end
        #~ end
    end

    def on_window_focus(*args)
        #puts 'focused window'
        @messageinput.grab_focus# unless @messageinput.focus?
        false
    end

    def scroll_up
        adjustment = @messagescroll.vadjustment
        adjustment.value =  adjustment.value - adjustment.page_increment
    end

    def scroll_down
        adjustment = @messagescroll.vadjustment
        x = adjustment.value + adjustment.page_increment
        x= adjustment.upper-adjustment.page_size if x > adjustment.upper-adjustment.page_size
        adjustment.value = x
    end

    #~ def switchtab(number)
    #~ tab = @main.tabmodel.number2tab(number.to_i)
    #~ @main.tabmodel.set_active(tab)
    #~ end

    def open_linkwindow
#         LinkWindow.new(@currentbuffer.links)
    end

    def open_preferences
        update_dimensions
        configwindow = ConfigWindow.new(@main)
        configwindow.show_all
    end

    def do_disconnect
        @main.disconnect
    end

    def open_networks
        if @networkpresence and @networkpresence.open?
            @networkpresence.focus
        else
            @networkpresence = NetworkPresenceConf.new(@main, @main.networks, @main.protocols)
        end
    end

    def open_plugins
        if @pluginwindow and @pluginwindow.open?
            @pluginwindow.focus
        else
            @pluginwindow = PluginWindow.new(@main)
        end
    end

    def open_keybindings
        if  @keybindingwindow and @keybindingwindow.open?
            @keybindingswindow.open
        else
            @keybindingwindow = KeyBindingWindow.new(@main, @config['keybindings'], @bindable_functions)
        end
    end

    def quit(notifymain=true)
        update_dimensions
        @main.quit if notifymain
    end
end
