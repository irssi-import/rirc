
class MainWindow
	attr_reader :currentchan
	def initialize
		puts 'starting main window'
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
		
		#~ @glade['window1'].signal_connect('configure_event') do |widget, event|
			#~ $config.set_value('windowwidth', event.width)
			#~ $config.set_value('windowheight', event.height)
			#~ #for some reason we need a nil here or the window contents don't resize
			#~ nil
		#~ end
		
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
		
		puts $config['channellistposition']

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
		
		@path= $path
		
		@me = self
		
		@last = nil
		
		puts @messages.modify_bg(Gtk::STATE_NORMAL, $config['backgroundcolor'])
		puts @messages.modify_fg(Gtk::STATE_NORMAL, $config['foregroundcolor'])
		puts @messages.modify_bg(Gtk::STATE_SELECTED, $config['selectedbackgroundcolor'])
		puts @messages.modify_fg(Gtk::STATE_SELECTED, $config['selectedforegroundcolor'])
		
		@messages.modify_bg(Gtk::STATE_NORMAL, $config['backgroundcolor'])
		@messages.modify_fg(Gtk::STATE_NORMAL, $config['foregroundcolor'])
		@messages.modify_bg(Gtk::STATE_PRELIGHT, $config['backgroundcolor'])
		@messages.modify_fg(Gtk::STATE_PRELIGHT, $config['foregroundcolor'])
		@messages.modify_bg(Gtk::STATE_ACTIVE, $config['backgroundcolor'])
		@messages.modify_fg(Gtk::STATE_ACTIVE, $config['foregroundcolor'])
		
		style = @messages.modifier_style
		puts style.bg(Gtk::STATE_NORMAL)
		#style.set_bg(Gtk::STATE_NORMAL, $config['backgroundcolor'])
		#style.set_fg(Gtk::STATE_NORMAL, $config['foregroundcolor'])
		
		@messages.modify_style(style)
		
		#connect
		
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
		
		@glade['window1'].resize(x, y)
		@glade['window1'].show
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
			presence = $presence
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
	
	def quit
		#$main.send_command('quit', 'quit')
		#@connection.close if @connection
		$config.set_value('panelposition', @panel.position)
		Gtk.main_quit
		$main.quit
	end
end