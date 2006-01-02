
class MainWindow
    attr_reader :currentbuffer, :tabmodel
    include KeyBind
    def initialize
        @glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
        
        @channelbuttonlock = false
        
        @serverlist = $main.serverlist
        @usernamebutton = @glade["username"]
        @topic = @glade["topic"]
        @messageinput = @glade["message_input"]
        @messagescroll = @glade['message_scroll']
        @messagevadjustment = @messagescroll.vadjustment
        
        @tooltips = Gtk::Tooltips.new
		
        @messageinput.grab_focus
        @messageinput.signal_connect("key_press_event"){|widget, event| input_buttons(widget, event)}

        @userlist = @glade['userlist']
        @panel = @glade['hpaned1']
        @mainbox = @glade['mainbox']
        @messagebox = @glade['vbox2']
        @preferencesbar = @glade['preferencesbar']
        @usercount = @glade['usercount']
        @currentbuffer = @serverlist
        drawuserlist(false)
        @messagescroll.add(@serverlist.view.view)
        @connection = nil
        @tablist = nil
        
        even = $config['scw_even'].to_hex
        odd = $config['scw_odd'].to_hex
        
        Gtk::RC.parse_string("style \"scwview\" {
                      ScwView::even-row-color = \"#{even}\"
                       ScwView::odd-row-color = \"#{odd}\"
                       ScwView::column-spacing = 5
                       ScwView::row-padding = 2
                       }\n
                       widget \"*.ScwView\" style \"scwview\"")
        
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
        #@keyintmap = {'q' => 11, 'w' => 12, 'e' => 13, 'r' => 14, 't'=> 15, 'y' => 16, 'u' => 17, 'i' => 18, 'o' => 19, 'p' => 20}
    end
	
    def draw_from_config(unhide=true)
        puts 'drawing'
        return if $main.quitting
        #@serverlist.redraw
        redraw_channellist
        #resize the window if we have some saved sizes...
        x = -1
        y = -1
        
        x = $config['windowwidth'].to_i if $config['windowwidth']
        y = $config['windowheight'].to_i if $config['windowheight']
        
        @glade['window1'].default_width = x
        @glade['window1'].default_height = y
        @glade['window1'].resize(x, y)
        
        @panel.position = $config['panelposition'].to_i if $config['panelposition']
        
        even = $config['scw_even'].to_hex
        odd = $config['scw_odd'].to_hex
        
        Gtk::RC.parse_string("style \"scwview\" {
                        ScwView::even-row-color = \"#{even}\"
                        ScwView::odd-row-color = \"#{odd}\"
                        ScwView::column-spacing = 5
                        ScwView::row-padding = 2
                        }\n
                        widget \"*.ScwView\" style \"scwview\"")
        
        @font = Pango::FontDescription.new($config['main_font'])
        
        update_view(@serverlist.view.view)
        @serverlist.servers.each do |server|
            update_view(server.view.view)
            server.channels.each {|channel| update_view(channel.view.view)}
            server.chats.each {|chat| update_view(chat.view.view)}
        end
        
        #TODO - figure out how to set the cursor-color style var (its undocumented, might not be in ruby-gtk2)
        #maybe use parse_string like for scwview
        
        if unhide
            @glade['window1'].show_all
        end
        @messageinput.grab_focus
    end
    
    def update_view(view)
        view.reset_rc_styles
        view.align_presences = $config['scw_align_presences']
        view.modify_text(Gtk::STATE_NORMAL, Gdk::Color.new(*$config['foregroundcolor']))
        view.modify_text(Gtk::STATE_SELECTED, Gdk::Color.new(*$config['selectedforegroundcolor']))
        view.modify_base(Gtk::STATE_SELECTED, Gdk::Color.new(*$config['selectedbackgroundcolor']))
        view.modify_text(Gtk::STATE_ACTIVE, Gdk::Color.new(*$config['selectedforegroundcolor']))
        view.modify_base(Gtk::STATE_ACTIVE, Gdk::Color.new(*$config['selectedbackgroundcolor']))
        
        view.modify_text(Gtk::STATE_PRELIGHT, Gdk::Color.new(*$config['scw_prelight']))
        view.modify_font(@font)
    end
	
    def redraw_channellist
        if @tablist
            if @glade['h_top'].children.include?(@tablist.widget)
                @glade['h_top'].remove(@tablist.widget)
            elsif @glade['v_top'].children.include?(@tablist.widget)
                @glade['v_top'].remove(@tablist.widget)
            elsif @glade['u_pane'].children.include?(@tablist.widget)
                @glade['u_pane'].remove(@tablist.widget)
            end
        end
        
        if $config['tablisttype'] == 'treeview'
            if $config['tablistposition'] != 'right' and $config['tablistposition'] != 'left' and $config['tablistposition'] != 'underuserlist'
                $config['tablistposition'] = 'left'
            end
            unless @tablist.class == TreeTabList
                $main.tabmodel.delete_observer(@tablist)
                @tablist = TreeTabList.new($main.tabmodel)
            end
        else
            if $config['tablistposition'] == 'right' or $config['tablistposition'] == 'left' or $config['tablistposition'] == 'underuserlist'
                unless @tablist.class == VBoxTabList
                    $main.tabmodel.delete_observer(@tablist)
                    @tablist = VBoxTabList.new($main.tabmodel)
                end
            else
                unless @tablist.class == HBoxTabList
                    $main.tabmodel.delete_observer(@tablist)
                    @tablist = HBoxTabList.new($main.tabmodel)
                end
            end
        end
        
        $main.tabmodel.set_sort_and_structure(*$config.gettabmodelconfig)
        @tablist.renumber
            
        if $config['tablistposition'] == 'right'
            @glade['h_top'].pack_start(@tablist.widget, false, false, 5)
        elsif $config['tablistposition'] == 'left'
            @glade['h_top'].pack_start(@tablist.widget, false, false, 5)
            @glade['h_top'].reorder_child(@tablist.widget, 0)
        elsif $config['tablistposition'] == 'top'
            @glade['v_top'].pack_start(@tablist.widget, false, false, 5)
            @glade['v_top'].reorder_child(@tablist.widget, 0)
        elsif $config['tablistposition'] == 'bottom'
            @glade['v_top'].pack_start(@tablist.widget, false, false, 5)
        elsif $config['tablistposition'] == 'underuserlist'
            @glade['u_pane'].pack2(@tablist.widget, false, true)
        end
        #@tablist.widget.show_all
    end
	
	def set_username
        x = nil
        label = Gtk::Label.new("New username")
        entry = Gtk::Entry.new
        entry.text = @currentbuffer.server.username
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
        $main.send_command('nick'+x, 'presence change;network='+@currentbuffer.server.name+';mypresence='+@currentbuffer.server.presence+';name='+x) if x
    end
	
	def topic_change(widget)
        if widget.text != @currentbuffer.topic and @currentbuffer.class == ChannelBuffer
            $main.send_command('topicchange', 'channel change;network='+@currentbuffer.server.name+';mypresence='+@currentbuffer.server.presence+';channel='+@currentbuffer.name+';topic='+escape(widget.text))
        end
		#add_message("Topic changed to: "+ widget.text, 'notice')
	end
	
    #get the substring to use for tab completion.
	def get_completion_substr
		string = @messageinput.text
		position = @messageinput.position
		string = string[0, position]
		name, whatever = string.reverse.split(' ', 2)
        
        return nil unless name
		
		name = name.reverse
		
		return name
	end
	
    #function to do the nick replace for tab completion
	def replace_completion_substr(substr, nick)
		string = @messageinput.text.rstrip
		position = @messageinput.position
		index = string.rindex(substr, position)
		
        #split the string by the cursor position
        a = string[0, position]
        b = string[position, string.length-position]

        #use rstrip to ignore traling whitespace for calculating the start of the nick
        nickstart = a.rstrip.length-substr.length
        #nick replace
		a = a.reverse.sub(substr.reverse, nick.reverse)
		a.reverse!
        #reassemble the string, converting the pieces to strings if they're nulls
        a ||= ''
        b ||= ''
        string = a+b

        nicklength = nick.length
        #determine current position and take action
		if index == 0
            #the beginning
			if string[nick.length, 1] == ' '
				string.insert(nick.length, $config['tabcompletesuffix'])
                nicklength = nick.length+2
			else
				string.insert(nick.length, $config['tabcompletesuffix']+' ')
                nicklength = nick.length+2
			end
		elsif index+nick.length == string.length
            #we're at the end
		else
            #somewhere in the middle
			if string[index+nick.length, 1] != ' '
				string.insert(nickstart+nick.length, ' ')
                nicklength = nick.length+1
            else
                nicklength = nick.length+1
			end
		end
        #update the content of the entry
		@messageinput.text = string
        #reposition the cursor
		@messageinput.set_position(nickstart+nicklength)
	end

	def switchchannel(channel)
		#make the new channel the current one, and toggle the buttons accordingly
        return unless channel
        #update_dimensions

		@currentbuffer.currentcommand = @messageinput.text
        if @currentbuffer.class == ChannelBuffer
            @userlist.remove_column(@currentbuffer.modecolumn)
            @userlist.remove_column(@currentbuffer.usercolumn)
        end
		@currentbuffer = channel
        drawuserlist(@currentbuffer.class == ChannelBuffer)
		@messageinput.text = @currentbuffer.currentcommand
		@messageinput.select_region(0, 0)
		@messageinput.position=-1
        @messagescroll.children.each {|child| @messagescroll.remove(child)}
        @messagescroll.add(@currentbuffer.view.view)
        @messagescroll.show_all
        
        @messagescroll.set_size_request(0, -1)#magical diamond skill 7 hack to stop window resizing
		@usernamebutton.label = @currentbuffer.username.gsub('_', '__') if @currentbuffer.username
        @currentbuffer.view.view.scroll_to_end
        @messageinput.grab_focus
	end
    
	def updateusercount
		return unless @currentbuffer.class == ChannelBuffer
        modes = {}
        modeorder = []
        @currentbuffer.users.users.each do |user|
            mode = user.get_mode
            if modes[mode]
                modes[mode] += 1
            elsif mode != ''
                modes[mode] = 1
                modeorder[user.decodemode(mode)] = mode
            end
        end
        
        modeorder.reverse!
        text = ''
        modeorder.each do |m|
            next if m == nil
            text +=modes[m].to_s+m+', '
        end
        
        text += @currentbuffer.users.users.length.to_s+' total'
        @usercount.text = text
	end
	
	def drawuserlist(toggle)
		if toggle
			@mainbox.remove(@messagebox)
			@mainbox.pack_start(@panel)
			@panel.add1(@messagebox)
			@messageinput.grab_focus
			@userlist.model = @currentbuffer.userlist
			@userlist.append_column(@currentbuffer.modecolumn)
            @userlist.append_column(@currentbuffer.usercolumn)
            @userlist.search_column=1
			@userlist.show_all
			@topic.show
			@topic.text =@currentbuffer.topic
            @tooltips.set_tip(@topic, @currentbuffer.topic, '')
			@usernamebutton.show
			updateusercount
		else
			@mainbox.remove(@panel)
			@panel.remove(@messagebox)
			@mainbox.pack_start(@messagebox)
			@messageinput.grab_focus
			@topic.hide
			@topic.text = ''
			if @currentbuffer.class == RootBuffer
				@usernamebutton.hide
			else
				@usernamebutton.show
			end
        end
	end
	
	def message_input(widget)
		return if widget.text.length == 0
		@currentbuffer.addcommand(widget.text)

		if @currentbuffer.class == ChannelBuffer
			network = @currentbuffer.server
			presence = @currentbuffer.server.presence
		elsif @currentbuffer.class == ChatBuffer
			network = @currentbuffer.server
			presence = @currentbuffer.server.presence
		elsif @currentbuffer.class == ServerBuffer
			network = @currentbuffer
			presence = @currentbuffer.presence
		else
			presence = $config['presence']
		end
		
		message = widget.text
        #puts '"'+message+'"'
		#$main.command_parse(message, network, presence, @currentbuffer)
		$main.queue_input([message, network, presence, @currentbuffer])
		widget.text = ''
        @currentbuffer.gotolastcommand
	end
	
	def get_username
		@usernamebutton.label = @currentbuffer.username.gsub('_', '__')
	end
	
	def show_username
		@usernamebutton.show
	end
    
    def storecommand(x=true)
        text = @messageinput.text
        if text.length > 0
            @currentbuffer.addcommand(text, x)
        end
    end
	
	def getlastcommand
		@messageinput.text = @currentbuffer.getlastcommand
		@messageinput.grab_focus
	end
	
	def getnextcommand
		@messageinput.text = @currentbuffer.getnextcommand
		@messageinput.grab_focus
	end
    
    def update_dimensions
        puts 'updating dimensions'
        width, height = @glade['window1'].size
        $config['panelposition'] = @panel.position
        $config['windowwidth']=  width if width
        $config['windowheight'] = height if height
    end
	
    def updatetopic
            if @currentbuffer.class == ChannelBuffer
                    @topic.text =@currentbuffer.topic
        @tooltips.set_tip(@topic, @currentbuffer.topic, '')
            end
    end
    
    def userlist_on_click(widget, event)
		if event.button == 3
            path, column, x, y = @userlist.get_path_at_pos(event.x, event.y)
            return unless path
            @userlist.set_cursor(path, nil, false)
			userlist_popup_menu(event)
			return true
		end
    end
    
    def userlist_popup_menu(event)
        selection = @userlist.selection.selected
        if selection
            menu = create_user_popup(selection[1])
            menu.show_all
            menu.popup(nil, nil, event.button, event.time)
        end
    end
    
    def userlist_on_doubleclick(treeview, path, column)
        iter = @userlist.model.get_iter(path)
        return if iter[1] == @currentbuffer.server.username
        if !chat = @currentbuffer.server.has_chat?(iter[1])
            chat = @currentbuffer.server.addchat(iter[1])
        end
        chat.connect unless chat.connected
        switchchannel(chat)
    end
	
	#~ def textview_on_click(widget, event)
		#~ x, y = widget.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, event.x, event.y)
		#~ if event.button == 1
			#~ textview_go_link(widget, x, y)
			#~ return false
		#~ elsif event.button == 3
			#~ textview_popup_menu(widget, event, x, y)
			#~ return true
		#~ end
	#~ end
	
	#~ def textview_motion_notify(widget, event)
		#~ x, y = widget.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, event.x, event.y)
		#~ textview_set_cursor(widget, x, y)
		#~ @x = event.x
		#~ @y = event.y
		#~ focus_input
		#~ return false
	#~ end
	
	#~ def textview_go_link(widget, x, y)
		#~ iter = widget.get_iter_at_location(x, y)
		
		#~ iter.tags.each do |tag|
			#~ next unless tag.name
			#~ name = tag.name.split('_', 3)
			#~ if name[0]  == 'link'
                #~ link = to_uri(name[2])
				#~ fork{exec($config['linkclickaction'].sub('%s', link))}
				#~ break
			#~ end
		#~ end
		
	#~ end
	
	#~ def textview_popup_menu(widget, event, x, y)
		#~ iter = widget.get_iter_at_location(x, y)
		#~ menu = @defaultmenu
		
		#~ iter.tags.each do |tag| 
			#~ next unless tag.name
			#~ name = tag.name.split('_', 3)
			#~ if name[0]  == 'link'
				#~ menu = create_link_popup(name[2])
				#~ break
			#~ elsif name[0] == 'user'
				#~ menu = create_user_popup(name[2])
				#~ break
			#~ end
		#~ end
		
		#~ menu.show_all
		#~ menu.popup(nil, nil, event.button, event.time)
	#~ end
	
	#~ def textview_set_cursor(textview, x, y)
		#~ hovering = false
		
		#~ iter = textview.get_iter_at_location(x, y)
		
		#~ @highlighted.each do |tag|
			#~ tag.underline = Pango::AttrUnderline::NONE
		#~ end
		
		#~ @highlighted = []
		
		#~ iter.tags.each do |tag|
			#~ next unless tag.name
			#~ name = tag.name.split('_', 3)
			#~ if name[0]  == 'link'
				#~ @highlighted.push(tag)
				#~ tag.underline = Pango::AttrUnderline::SINGLE
				#~ hovering = true
				#~ break
			#~ elsif name[0]  == 'user'
				#~ @highlighted.push(tag)
				#~ tag.underline = Pango::AttrUnderline::SINGLE
				#~ hovering = true
				#~ break
			#~ end
			#~ textview.signal_emit('populate_popup', @defaultmenu)
		#~ end

        #~ window = textview.get_window(Gtk::TextView::WINDOW_TEXT)
		#~ if hovering != @hoveringoverlink
			#~ @hoveringoverlink = hovering.deep_clone
			#~ if @hoveringoverlink
				#~ window.cursor = @linkcursor
			#~ else
				#~ window.cursor = @normalcursor
			#~ end
		#~ end
		#~ @glade['window1'].pointer
		#~ #I should probably change the GdkEventMask instead of this.... (or not...)
        #~ return false
	#~ end
	
	def create_link_popup(link)
		menu = Gtk::Menu.new
        link = to_uri(link)
        item = Gtk::MenuItem.new(link)
        item.sensitive = false
        menu.append(item)
		menu.append(Gtk::MenuItem.new("Open link in browser"))
		menu.append(Gtk::MenuItem.new("Copy link location"))
	end
	
	def create_user_popup(user)
            user = @currentbuffer.users[user] if @currentbuffer.users
            if user
                menu = Gtk::Menu.new
                menu.append(Gtk::MenuItem.new(user.name))
                menu.append(Gtk::MenuItem.new('hostname: '+user.hostname)) if user.hostname
                menu.append(Gtk::MenuItem.new('Last message: '+user.lastspoke.strftime('%H:%M')))
                whois = Gtk::MenuItem.new("Whois "+ user.name)
                whois.signal_connect('activate') do |w|
                        whois(user.name)
                end
                menu.append(whois)
            else
                menu = @defaultmenu
            end
	end
	
	def whois(user)
		return if @currentbuffer.class == RootBuffer
		network, presence = @currentbuffer.getnetworkpresencepair
		$main.send_command('whois'+user, 'presence status;network='+network+';mypresence='+presence+';presence='+user)
	end
        
    def input_buttons(widget, event)
        return unless event.class == Gdk::EventKey #ack, another guard against non EventKey events
        if event.keyval == Gdk::Keyval.from_name('Tab')
            if @currentbuffer.class == ChannelBuffer || @currentbuffer.class == ChatBuffer
                substr = get_completion_substr
                nick = @currentbuffer.tabcomplete(substr) if substr
                replace_completion_substr(substr, nick) if nick
            end
        else
            if @currentbuffer.class == ChannelBuffer || @currentbuffer.class == ChatBuffer
                @currentbuffer.clear_tabcomplete
            end
        end
            
        if event.keyval == Gdk::Keyval.from_name('Up')
            storecommand(false)
            getlastcommand
        elsif event.keyval == Gdk::Keyval.from_name('Down')
            storecommand
            getnextcommand
        elsif event.keyval == Gdk::Keyval.from_name('Tab')
            true
        end
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
        return unless x and $config['keybindings'][x]
        command, args = $config['keybindings'][x].split('(', 2)
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
    
    def switchtab(number)
        tab = $main.tabmodel.number2tab(number.to_i)
        $main.tabmodel.set_active(tab)
    end
    
    def open_linkwindow
        LinkWindow.new(@currentbuffer.links)
    end

    def open_preferences
        update_dimensions
        configwindow = ConfigWindow.new
        configwindow.show_all
    end
    
    def do_disconnect
        $main.disconnect
    end
    
    def open_networks
        if @networkpresence and @networkpresence.open?
            @networkpresence.focus
        else
            @networkpresence = NetworkPresenceConf.new($main.networks, $main.protocols)
        end
    end
    
    def open_plugins
        if @pluginwindow and @pluginwindow.open?
            @pluginwindow.focus
        else
            @pluginwindow = PluginWindow.new
        end
    end
    
    def open_keybindings
        if  @keybindingwindow and @keybindingwindow.open?
            @keybindingswindow.open
        else
            @keybindingwindow = KeyBindingWindow.new($config['keybindings'], @bindable_functions)
	end
    end
    
    def quit
        update_dimensions
        $main.quit
    end
end