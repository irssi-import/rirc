
class MainWindow
	attr_reader :currentchan
	def initialize
		@serverlist = $main.serverlist
		@glade = GladeXML.new("glade/rirc.glade") {|handler| method(handler)}
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
		@channellist = @glade['channellist']
		@userbar = @glade['userbar']
		@userlist = @glade['userlist']
		@panel = @glade['hpaned1']
		@mainbox = @glade['mainbox']
		@messagebox = @glade['vbox2']
		@configwindow = @glade['config']
		@preferencesbar = @glade['preferencesbar']
		@channellist.pack_start(@serverlist.box, false, false)
		@currentchan = @serverlist
		drawuserlist(false)
		@messages.buffer = @serverlist.buffer
		@serverlist.button.active = true
		@connection = nil
		
		@path= $path
		
		@me = self
		
		@last = nil
		#connect
		
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
	
	def getlastcommand
		@messageinput.text = @currentchan.getlastcommand
		@messageinput.grab_focus
	end
	
	def getnextcommand
		@messageinput.text = @currentchan.getnextcommand
		@messageinput.grab_focus
	end
	
	def on_preferences1_activate
		
		#puts 'decorated' if @configwindow.decorated?
		@cells = Gtk::CellRendererText.new
		@cells.text = "bleh"
		#puts @preferencesbar.insert_column(1, 'Preferences', @cells, {}).to_s 
		@configwindow.show_all
	end
	
	def quit
		#$main.send_command('quit', 'quit')
		#@connection.close if @connection
		Gtk.main_quit
		$main.quit
	end
end