
class MainWindow
	attr_reader :currentbuffer
	def initialize
		#puts 'starting main window'
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
		
		
		@channelbuttonlock = false
		
		@serverlist = $main.serverlist
		@usernamebutton = @glade["username"]
		@topic = @glade["topic"]
		@messages = @glade["message_window"]
		@messageinput = @glade["message_input"]
		@messagescroll = @glade['message_scroll']
		@messagescroll.vadjustment.signal_connect('value-changed') do |w|
			#~ puts w.value.to_s
			#~ puts w.page_size.to_s
			#~ puts w.lower.to_s
			#~ puts w.upper.to_s
			#~ puts @messages.buffer.line_count.to_s
			#~ puts '---'
			
		end
		
		#@messageinput.signal_connect("selection_received") { |x, y, z| puts 'selection changed'}
		
		@messageinput.grab_focus
		@messageinput.signal_connect("key_press_event") do |widget, event|
			#puts Gdk::Keyval.to_name(event.keyval)
			if event.keyval == Gdk::Keyval.from_name('Tab')
				if @currentbuffer.class == ChannelBuffer
					substr = get_completion_substr
					#puts substr
					nick = @currentbuffer.tabcomplete(substr)
					#@messageinput.text = nick if nick
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
		#~ if $config['channellistposition'] == 'right' or $config['channellistposition'] == 'left'
			#~ @channellist = @glade['channellist_side']
		#~ else
			#~ @channellist = @glade['channellist_top']
		#~ end
		
		#puts $config['channellistposition']

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
		#@messages.signal_connect('key_press_event') do |widget, event|
			#if event.keyval
				#puts Gdk::Keyval.to_unicode(event.keyval)
				
				#focus_input
				#@messageinput.signal_emit('key_press_event', event)
				#@messageinput.delete_selection
			#end
		#end
		#~ @messages.key_snooper_install do |widget, event|
			#~ focus input
			#~ @messageinput.signal_emit('key_press_event', event)
			#~ return true
		#~ end
		
		@me = self
		
		@last = nil
		
		@highlighted = []
		
		@defaultmenu = Gtk::Menu.new
		@defaultmenu.append(Gtk::MenuItem.new("thing1"))
		@defaultmenu.append(Gtk::MenuItem.new("thing2"))
		
	end
	
	def draw_from_config
		@serverlist.redraw
		redraw_channellist
		@panel.position = $config['panelposition'].to_i if $config['panelposition']
		#resize the window if we have some saved sizes...
		x = -1
		y = -1
		
		x = $config['windowwidth'].to_i if $config['windowwidth']
		y = $config['windowheight'].to_i if $config['windowheight']
		
		@messages.modify_base(Gtk::STATE_NORMAL, $config['backgroundcolor'])
		@messages.modify_text(Gtk::STATE_NORMAL, $config['foregroundcolor'])
		
		#puts $config['selectedbackgroundcolor'], $config['selectedforegroundcolor']
		
		@messages.modify_base(Gtk::STATE_SELECTED, $config['selectedbackgroundcolor'])
		@messages.modify_text(Gtk::STATE_SELECTED, $config['selectedforegroundcolor'])
		
        font = Pango::FontDescription.new($config['main_font'])
        
        @messages.modify_font(font)
        
		@glade['window1'].resize(x, y)
		@glade['window1'].show
		@messageinput.grab_focus
	end
	
	def redraw_channellist
		 if @channellist
			@channellist.remove(@serverlist.box)
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
	
	#def on_message_window_button_release_event
#		@messageinput.focus=true
	#end

	def scroll_to_end(channel)
		return if @currentbuffer != channel
		#check if we were at the end before the message was sent, if so, move down again
		if mark_onscreen?(@currentbuffer.oldendmark)
			#puts 'onscreen'
			@messages.scroll_to_mark(@currentbuffer.endmark, 0.0, false,  0, 0)
		else
			#puts 'not onscreen'
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
	
	def get_completion_substr
		string = @messageinput.text
		position = @messageinput.position
		#puts position
		string = string[0, position]
		#puts string
		name, whatever = string.reverse.split(' ', 2)
		
		name = name.reverse
		
		return name
	end
	
	def replace_completion_substr(substr, nick)
		nick = nick
		string = @messageinput.text.rstrip
		position = @messageinput.position
		index = string.rindex(substr, position)
		
		string = string.reverse.sub(substr.reverse, nick.reverse)
		string.reverse!
		#index = string.rindex(nick)
		#puts index
		if index == 0
			if string[nick.length, 1] == ' '
				string.insert(nick.length, ';')
			else
				string.insert(nick.length, '; ')
			end
		elsif index+nick.length == string.length
			#~ puts index
			#~ puts nick.length
			#~ puts index+nick.length
			#~ puts string.length
			#puts 'end'
		else
			if string[index+nick.length, 1] != ' '
				string.insert(index+nick.length, ' ')
			end
			#puts 'middle'
		end
		@messageinput.text = string
		@messageinput.set_position(index+nick.length+1)
	end

	def switchchannel(channel)
		#make the new channel the current one, and toggle the buttons accordingly
		if !channel.button.active? or channel == @currentbuffer
			if @currentbuffer == channel and @currentbuffer.button.active? == false
				@currentbuffer.activate
				return
			end
		end
		@currentbuffer.currentcommand = @messageinput.text
		@currentbuffer.deactivate
		@userlist.remove_column(@currentbuffer.column) if @currentbuffer.class == ChannelBuffer
		@currentbuffer = channel
		@messageinput.text = @currentbuffer.currentcommand
		@messageinput.select_region(0, 0)
		@messageinput.position=-1
		#@messageinput.delete_selection
		#~ selection = Gdk::EventSelection.new(Gdk::Event::SELECTION_CLEAR)
		#~ @messageinput.signal_emit('selection_clear_event', selection)
		#~ @messageinput.signal_emit('selection_notify_event', selection)
		@messages.buffer = @currentbuffer.activate
		@messages.scroll_to_mark(@currentbuffer.endmark, 0.0, false,  0, 0)
		@usernamebutton.label = @currentbuffer.username.gsub('_', '__') if @currentbuffer.username
		drawuserlist(@currentbuffer.class == ChannelBuffer)
	end
	
	def updateusercount
		return if @currentbuffer.class == RootBuffer
		#puts 'updating user count'
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
            @panel.position = $config['panelposition'].to_i if $config['panelposition']
            #resize the window if we have some saved sizes...
            x = -1
            y = -1
            
            x = $config['windowwidth'].to_i if $config['windowwidth']
            y = $config['windowheight'].to_i if $config['windowheight']
            @panel.position = $config['panelposition'].to_i if $config['panelposition']
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
		
		#channel = @currentbuffer.name
		if @currentbuffer.class == ChannelBuffer
			network = @currentbuffer.server.name
			presence = @currentbuffer.server.presence
		elsif @currentbuffer.class == ChatBuffer
			network = @currentbuffer.server.name
			presence = @currentbuffer.server.presence
		elsif @currentbuffer.class == ServerBuffer
			network = @currentbuffer.name
			presence = @currentbuffer.presence
		else
			presence = $config['presence']
		end
		
		message = widget.text
		$main.handle_input(message, @currentbuffer, network, presence)
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
	
	def on_preferences1_activate
		configwindow = ConfigWindow.new
		configwindow.show_all
	end
	
	def updatetopic
		if @currentbuffer.class == ChannelBuffer
			@topic.text =@currentbuffer.topic
		end
	end
	
	def window_resized(window, event)
		$config.set_value('windowwidth', event.width)
		$config.set_value('windowheight', event.height)
		#for some reason we need to return a nil here or the window contents won't resize
		nil
	end
    
    def userlist_on_click(widget, event)
		if event.button == 3
			userlist_popup_menu(event)
			return true
		end
    end
    
    def userlist_popup_menu(event)
        selection = @userlist.selection.selected
        #puts selection.class
        if selection
            #puts selection[0]
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
			#puts tag.name
			name = tag.name.split('_', 3)
			if name[0]  == 'link'
				puts 'clicked tag linking to '+name[2]
                link = to_uri(name[2])
				system($config['linkclickaction'].sub('%s', link))
				break
			#elsif tag.data['type']  == 'user'
			#	puts 'clicked tag linking to '+tag.data['user'].to_s
			#	break
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
			#puts tag.name
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
			#tag.foreground = 'black'
			tag.underline = Pango::AttrUnderline::NONE
		end
		
		@highlighted = []
		
		iter.tags.each do |tag|
			next unless tag.name
			#puts tag.name
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
		
		#need to set the GdkWindowAttributesType for the gdk::window so the cursor change works
		#~ if hovering != @hoveringoverlink
			#~ @hoveringoverlink = hovering.deep_clone
			#~ if @hoveringoverlink
				#~ @textview.parent_window.cursor = @linkcursor
			#~ else
				#~ @textview.parent_window.cursor = @normalcursor
			#~ end
		#~ end
		@glade['window1'].pointer
		#I should probably change the GdkEventMask instead of this....
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
				puts 'requested whois for '+user.name
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
	
	def focus_input
		start = @currentbuffer.buffer.get_iter_at_mark(@currentbuffer.buffer.selection_bound)
		stop = @currentbuffer.buffer.get_iter_at_mark(@currentbuffer.buffer.get_mark('insert'))
		if @currentbuffer.buffer.get_text(start, stop).length <= 0
			#puts 'no selection'
			@messageinput.grab_focus
			@messageinput.select_region(0, 0)
			@messageinput.position=-1
			#@messageinput.delete_selection
		else
			@messages.grab_focus
		end
	end
	
	def quit
		#$main.send_command('quit', 'quit')
		#@connection.close if @connection
		$config.set_value('panelposition', @panel.position)
		Gtk.main_quit
		$main.quit
	end
end