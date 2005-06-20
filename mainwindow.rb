
class MainWindow
	attr_reader :currentchan
	def initialize
		puts 'starting main window'
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
		
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
		@messageinput.grab_focus
		@messageinput.signal_connect("key_press_event") do |widget, event|
			if event.keyval == Gdk::Keyval.from_name('Up')
				getlastcommand
			elsif event.keyval == Gdk::Keyval.from_name('Down')
				getnextcommand
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
		@currentchan = @serverlist
		drawuserlist(false)
		@messages.buffer = @serverlist.buffer
		@serverlist.button.active = true
		@connection = nil
		
		@messages.signal_connect('motion_notify_event') { |widget, event| textview_motion_notify(widget, event)}
		@messages.signal_connect('button_press_event') { |widget, event| textview_on_click(widget, event)}
		
		@path= $path
		
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
		
		@messages.modify_base(Gtk::STATE_SELECTED, $config['selectedbackgroundcolor'])
		@messages.modify_text(Gtk::STATE_SELECTED, $config['selectedforegroundcolor'])
		
		
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
		return if @currentchan != channel
		#check if we were at the end before the message was sent, if so, move down again
		if mark_onscreen?(@currentchan.oldendmark)
			#puts 'onscreen'
			@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
		else
			#puts 'not onscreen'
		end
	end
	
	def mark_onscreen?(mark)
		return iter_onscreen?(@currentchan.buffer.get_iter_at_mark(mark))
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

	
	def switchchannel(channel)
		#make the new channel the current one, and toggle the buttons accordingly
		return if @currentchan == channel
		@currentchan.deactivate
		@userlist.remove_column(@currentchan.column) if @currentchan.class == Channel
		@currentchan = channel
		@messages.buffer = @currentchan.activate
		@messages.scroll_to_mark(@currentchan.endmark, 0.0, false,  0, 0)
		@usernamebutton.label = @currentchan.username.gsub('_', '__') if @currentchan.username
		drawuserlist(@currentchan.class == Channel)
	end
	
	def updateusercount
		#puts 'updating user count'
		@usercount.text = @currentchan.users.users.length.to_s+" users"
	end
	
	def drawuserlist(toggle)
		if toggle
			@mainbox.remove(@messagebox)
			@mainbox.pack_start(@panel)
			@panel.add1(@messagebox)
			@messageinput.grab_focus
			@userlist.model = @currentchan.userlist
			@userlist.append_column(@currentchan.column)
			@userlist.show_all
			@topic.show
			@topic.text =@currentchan.topic
			@usernamebutton.show
			updateusercount
		else
			@mainbox.remove(@panel)
			@panel.remove(@messagebox)
			@mainbox.pack_start(@messagebox)
			@messageinput.grab_focus
			@topic.hide
			@topic.text = ''
			if @currentchan.class == ServerList
				@usernamebutton.hide
			else
				@usernamebutton.show
			end
		end
	end
	
	def message_input(widget)
		return if widget.text.length == 0
		@currentchan.addcommand(widget.text)
		
		channel = @currentchan.name
		if @currentchan.class == Channel
			network = @currentchan.server.name
			presence = @currentchan.server.presence
		elsif @currentchan.class == Server
			network = @currentchan.name
			presence = @currentchan.presence
		else
			presence = $config['presence']
		end
		
		message = widget.text
		$main.handle_input(message, channel, network, presence)
		widget.text = ''
	end
	
	def get_username
		@usernamebutton.label = @currentchan.username.gsub('_', '__')
	end
	
	def show_username
		@usernamebutton.show
	end
	
	def getlastcommand
		@messageinput.text = @currentchan.getlastcommand
		@messageinput.grab_focus
	end
	
	def getnextcommand
		@messageinput.text = @currentchan.getnextcommand
		@messageinput.grab_focus
	end
	
	def on_preferences1_activate
		configwindow = ConfigWindow.new
		configwindow.show_all
	end
	
	def updatetopic
		if @currentchan.class == Channel
			@topic.text =@currentchan.topic
		end
	end
	
	def window_resized(window, event)
		$config.set_value('windowwidth', event.width)
		$config.set_value('windowheight', event.height)
		#for some reason we need to return a nil here or the window contents won't resize
		nil
	end
	
	def textview_on_click(widget, event)
		x, y = widget.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, event.x, event.y)
		if event.button == 1
			textview_go_link(widget, x, y)
		elsif event.button == 3
			textview_popup_menu(widget, event, x, y)
		end
		true
	end
	
	def textview_motion_notify(widget, event)
		x, y = widget.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, event.x, event.y)
		textview_set_cursor(widget, x, y)
		@x = event.x
		@y = event.y
	end
	
	def textview_go_link(widget, x, y)
		iter = widget.get_iter_at_location(x, y)
		
		iter.tags.each do |tag|
			name = tag.name.split('_', 3)
			if name[0]  == 'link'
				puts 'clicked tag linking to '+name[2]
				system($config['linkclickaction'].sub('%s', name[2]))
				break
			#elsif tag.data['type']  == 'user'
			#	puts 'clicked tag linking to '+tag.data['user'].to_s
			#	break
			end
		end
		
	end
	
	def textview_popup_menu(widget, event, x, y)
		iter = widget.get_iter_at_location(x, y)
		menu = @defaultmenu
		
		iter.tags.each do |tag| 
			#puts tag
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
			tag.foreground = 'black'
			tag.underline = Pango::AttrUnderline::NONE
		end
		
		@highlighted = []
		
		iter.tags.each do |tag| 
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
		menu.append(Gtk::MenuItem.new("Open link in browser"))
		menu.append(Gtk::MenuItem.new("Copy link location"))
	end
	
	def create_user_popup(user)
		menu = Gtk::Menu.new
		menu.append(Gtk::MenuItem.new("User"))
		menu.append(Gtk::MenuItem.new("Whois user"))
	end
	
	def focus_input
		@messageinput.grab_focus
	end
	
	def quit
		#$main.send_command('quit', 'quit')
		#@connection.close if @connection
		$config.set_value('panelposition', @panel.position)
		Gtk.main_quit
		$main.quit
	end
end