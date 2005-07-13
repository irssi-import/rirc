
class MainWindow
	attr_reader :currentbuffer
	def initialize
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
		
		@channelbuttonlock = false
		
		@serverlist = $main.serverlist
		@usernamebutton = @glade["username"]
		@topic = @glade["topic"]
		@messages = @glade["message_window"]
		@messageinput = @glade["message_input"]
		@messagescroll = @glade['message_scroll']
        @messagevadjustment = @messagescroll.vadjustment
		
		@messageinput.grab_focus
		@messageinput.signal_connect("key_press_event") do |widget, event|
			if event.keyval == Gdk::Keyval.from_name('Tab')
				if @currentbuffer.class == ChannelBuffer
					substr = get_completion_substr
					nick = @currentbuffer.tabcomplete(substr) if substr
					replace_completion_substr(substr, nick) if nick
				end
			else
				if @currentbuffer.class == ChannelBuffer
					@currentbuffer.clear_tabcomplete
				end
			end
			
			if event.keyval == Gdk::Keyval.from_name('Up')
				getlastcommand
			elsif event.keyval == Gdk::Keyval.from_name('Down')
				getnextcommand
			elsif event.keyval == Gdk::Keyval.from_name('Tab')
				true
			end
		end

		@userbar = @glade['userbar']
		@userlist = @glade['userlist']
		@panel = @glade['hpaned1']
		@mainbox = @glade['mainbox']
		@messagebox = @glade['vbox2']
		@preferencesbar = @glade['preferencesbar']
		@usercount = @glade['usercount']
		@currentbuffer = @serverlist
		drawuserlist(false)
		@messages.buffer = @serverlist.buffer
		@serverlist.button.active = true
		@connection = nil
		
		@messages.signal_connect('motion_notify_event') { |widget, event| textview_motion_notify(widget, event)}
		@messages.signal_connect('button_press_event') { |widget, event| textview_on_click(widget, event)}
        
        @glade['window1'].signal_connect('key_press_event') { |widget, event| window_buttons(widget, event)}
		
		@me = self
		
		@last = nil
		
		@highlighted = []
        
        @linkcursor = Gdk::Cursor.new(Gdk::Cursor::HAND2)
        @normalcursor = Gdk::Cursor.new(Gdk::Cursor::LEFT_PTR)
		
		@defaultmenu = Gtk::Menu.new
		@defaultmenu.append(Gtk::MenuItem.new("thing1"))
		@defaultmenu.append(Gtk::MenuItem.new("thing2"))
        @keyintmap = {'q' => 11, 'w' => 12, 'e' => 13, 'r' => 14, 't'=> 15, 'y' => 16, 'u' => 17, 'i' => 18, 'o' => 19, 'p' => 20}
	end
	
	def draw_from_config(unhide=true)
		@serverlist.redraw
		redraw_channellist
        
		#resize the window if we have some saved sizes...
		x = -1
		y = -1
		
        x = $config['windowwidth'].to_i if $config['windowwidth']
		y = $config['windowheight'].to_i if $config['windowheight']
        @glade['window1'].resize(x, y)
        
        @panel.position = $config['panelposition'].to_i if $config['panelposition']
		
		@messages.modify_base(Gtk::STATE_NORMAL, $config['backgroundcolor'])
		@messages.modify_text(Gtk::STATE_NORMAL, $config['foregroundcolor'])
		
		@messages.modify_base(Gtk::STATE_SELECTED, $config['selectedbackgroundcolor'])
		@messages.modify_text(Gtk::STATE_SELECTED, $config['selectedforegroundcolor'])
		
        font = Pango::FontDescription.new($config['main_font'])
        
        @messages.modify_font(font)
        
        if unhide
            @glade['window1'].show
        end
		@messageinput.grab_focus
	end
	
	def redraw_channellist
		 if @channellist
			@channellist.remove(@serverlist.box) if @serverlist.box
			@channellist.destroy
		end
		
		if $config['channellistposition'] == 'right'
			@channellist = Gtk::VBox.new
			@glade['h_top'].pack_start(@channellist, false, false, 5)
		elsif $config['channellistposition'] == 'left'
			@channellist = Gtk::VBox.new
			@glade['h_top'].pack_start(@channellist, false, false, 5)
			@glade['h_top'].reorder_child(@channellist, 0)
		elsif $config['channellistposition'] == 'top'
			@channellist = Gtk::HBox.new
			@glade['v_top'].pack_start(@channellist, false, false, 5)
			@glade['v_top'].reorder_child(@channellist, 0)
		elsif $config['channellistposition'] == 'bottom'
			@channellist = Gtk::HBox.new
			@glade['v_top'].pack_start(@channellist, false, false, 5)
		end
		@channellist.show
		@channellist.pack_start(@serverlist.box, false, false)
	end
	
	def set_username
	end
	
	def topic_change(widget)
		#add_message("Topic changed to: "+ widget.text, 'notice')
	end
	
	def handle_input(string)
		@client.send(string+"\n", 0)
		@messageinput.text = ""
		return
	end

	def scroll_to_end(channel)
		return if @currentbuffer != channel
		#check if we were at the end before the message was sent, if so, move down again
		if mark_onscreen?(@currentbuffer.oldendmark)
			#@messages.scroll_to_mark(@currentbuffer.endmark, 0.0, false,  0, 0)
            @messages.scroll_mark_onscreen(@currentbuffer.endmark)
		end
	end
	
	def mark_onscreen?(mark)
		return iter_onscreen?(@currentbuffer.buffer.get_iter_at_mark(mark))
	end
	
	def iter_onscreen?(iter)
		rect = @messages.visible_rect
		y, height = @messages.get_line_yrange(iter)
		
		if y >= rect.y and y <= rect.y+rect.height
			return true
		else
			return false
		end
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
				string.insert(nick.length, ';')
                nicklength = nick.length+2
			else
				string.insert(nick.length, '; ')
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
        update_dimensions
        if channel.button.active? or channel == @channelbuffer
            if !@currentbuffer.button.active? and channel == @currentbuffer
                @currentbuffer.activate
                return
            elsif channel == @currentbuffer
                return
            end
        end
        #puts @currentbuffer.name, channel.name
		@currentbuffer.currentcommand = @messageinput.text
		@currentbuffer.deactivate
		@userlist.remove_column(@currentbuffer.column) if @currentbuffer.class == ChannelBuffer
		@currentbuffer = channel
		@messageinput.text = @currentbuffer.currentcommand
		@messageinput.select_region(0, 0)
		@messageinput.position=-1
		@messages.buffer = @currentbuffer.activate
        #~ @messagevadjustment.value = @messagevadjustment.upper
        #~ puts @messagevadjustment.lower
        #~ puts @messagevadjustment.upper
        #~ puts @messagevadjustment.value
        #~ @messagevadjustment.clamp_page(0, 100)
        #~ @messagevadjustment.changed
        #~ @messagevadjustment.value_changed
        #~ puts @messagevadjustment.lower
        #~ puts @messagevadjustment.upper
        #~ puts @messagevadjustment.value
        #~ puts ''
		#@messages.scroll_to_mark(@currentbuffer.endmark, 0.0, false,  0, 0)
        @messages.scroll_mark_onscreen(@currentbuffer.endmark)
        @messages.scroll_mark_onscreen(@currentbuffer.endmark)
		@usernamebutton.label = @currentbuffer.username.gsub('_', '__') if @currentbuffer.username
		drawuserlist(@currentbuffer.class == ChannelBuffer)
        @messagescroll.set_size_request(0, -1)#magical diamond skill 7 hack to stop window resizing
	end
	
	def updateusercount
		return unless @currentbuffer.class == ChannelBuffer
		@usercount.text = @currentbuffer.users.users.length.to_s+" users"
	end
	
	def drawuserlist(toggle)
		if toggle
			@mainbox.remove(@messagebox)
			@mainbox.pack_start(@panel)
			@panel.add1(@messagebox)
			@messageinput.grab_focus
			@userlist.model = @currentbuffer.userlist
			@userlist.append_column(@currentbuffer.column)
			@userlist.show_all
			@topic.show
			@topic.text =@currentbuffer.topic
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
		$main.command_parse(message, network, presence, @currentbuffer)
		widget.text = ''
	end
	
	def get_username
		@usernamebutton.label = @currentbuffer.username.gsub('_', '__')
	end
	
	def show_username
		@usernamebutton.show
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
        $config.set_value('panelposition', @panel.position) if @panel
        width, height = @glade['window1'].size if @glade['window1']
        $config.set_value('windowwidth', width) if width
		$config.set_value('windowheight', height) if height
    end
	
	def on_preferences1_activate
        update_dimensions
		configwindow = ConfigWindow.new
		configwindow.show_all
	end
	
	def updatetopic
		if @currentbuffer.class == ChannelBuffer
			@topic.text =@currentbuffer.topic
		end
	end
    
    def userlist_on_click(widget, event)
		if event.button == 3
			userlist_popup_menu(event)
			return true
		end
    end
    
    def userlist_popup_menu(event)
        selection = @userlist.selection.selected
        if selection
            menu = create_user_popup(selection[0])
            menu.show_all
            menu.popup(nil, nil, event.button, event.time)
        end
    end
	
	def textview_on_click(widget, event)
		x, y = widget.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, event.x, event.y)
		if event.button == 1
			textview_go_link(widget, x, y)
			return false
		elsif event.button == 3
			textview_popup_menu(widget, event, x, y)
			return true
		end
	end
	
	def textview_motion_notify(widget, event)
		x, y = widget.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, event.x, event.y)
		textview_set_cursor(widget, x, y)
		@x = event.x
		@y = event.y
		focus_input
		return false
	end
	
	def textview_go_link(widget, x, y)
		iter = widget.get_iter_at_location(x, y)
		
		iter.tags.each do |tag|
			next unless tag.name
			name = tag.name.split('_', 3)
			if name[0]  == 'link'
                link = to_uri(name[2])
				system($config['linkclickaction'].sub('%s', link))
				break
			end
		end
		
	end
    
    def to_uri(uri)
        if uri =~ /^[a-zA-Z]+\:\/\/.+/
            return uri
        else
            return 'http://'+uri
        end
    end
	
	def textview_popup_menu(widget, event, x, y)
		iter = widget.get_iter_at_location(x, y)
		menu = @defaultmenu
		
		iter.tags.each do |tag| 
			next unless tag.name
			name = tag.name.split('_', 3)
			if name[0]  == 'link'
				menu = create_link_popup(name[2])
				break
			elsif name[0] == 'user'
				menu = create_user_popup(name[2])
				break
			end
		end
		
		menu.show_all
		menu.popup(nil, nil, event.button, event.time)
	end
	
	def textview_set_cursor(textview, x, y)
		hovering = false
		
		iter = textview.get_iter_at_location(x, y)
		
		@highlighted.each do |tag|
			tag.underline = Pango::AttrUnderline::NONE
		end
		
		@highlighted = []
		
		iter.tags.each do |tag|
			next unless tag.name
			name = tag.name.split('_', 3)
			if name[0]  == 'link'
				@highlighted.push(tag)
				tag.underline = Pango::AttrUnderline::SINGLE
				hovering = true
				break
			elsif name[0]  == 'user'
				@highlighted.push(tag)
				tag.underline = Pango::AttrUnderline::SINGLE
				hovering = true
				break
			end
			textview.signal_emit('populate_popup', @defaultmenu)
		end

        window = textview.get_window(Gtk::TextView::WINDOW_TEXT)
		if hovering != @hoveringoverlink
			@hoveringoverlink = hovering.deep_clone
			if @hoveringoverlink
				window.cursor = @linkcursor
			else
				window.cursor = @normalcursor
			end
		end
		@glade['window1'].pointer
		#I should probably change the GdkEventMask instead of this.... (or not...)
        return false
	end
	
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
		$main.send_command('whois'+user, 'presence status;network='+network+';presence='+presence+';name='+user)
	end
    
    def window_buttons(widget, event)
    
        if event.state == Gdk::Window::MOD1_MASK
            key = Gdk::Keyval.to_name(event.keyval)
            if key =~ /\d/
                key = 10 if key.to_i == 0
                tab = @serverlist.number2tab(key.to_i)
                switchchannel(tab)
                return true
            elsif key =~ /[qwertyuiop]+/
                tab = @serverlist.number2tab(@keyintmap[key].to_i)
                switchchannel(tab)
                return true
            end
        end
    end
	
	def focus_input
		start = @currentbuffer.buffer.get_iter_at_mark(@currentbuffer.buffer.selection_bound)
		stop = @currentbuffer.buffer.get_iter_at_mark(@currentbuffer.buffer.get_mark('insert'))
		if @currentbuffer.buffer.get_text(start, stop).length <= 0
            position = @messageinput.position
			@messageinput.grab_focus
			@messageinput.select_region(0, 0)
			@messageinput.position= position
		else
			@messages.grab_focus
		end
	end
	
	def quit
        update_dimensions
		Gtk.main_quit
		$main.quit
	end
end