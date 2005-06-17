class ConnectionWindow
	def initialize
		@glade = GladeXML.new("glade/connect.glade") {|handler| method(handler)}
		@window = @glade['window1']
		
		@connection_log = @glade['connection_log']
		
		@ssh_button = @glade['ssh']
		@socket_button = @glade['socket'] 
		@net_ssh_button = @glade['net_ssh']
		@net_ssh_button.sensitive = false
		
		@ssh_button.active = true
		@config = {}
		
		@config[@ssh_button] = {}
		@config[@ssh_button]['host'] = 'localhost'
		@config[@ssh_button]['username'] = `whoami`.chomp
		@config[@ssh_button]['binpath'] = '/usr/bin/irssi2'
		
		@config[@socket_button] = {}
		@config[@socket_button]['location'] = ENV['HOME']+'/.irssi2/client-listener'
		
		@config[@net_ssh_button] = {}
		
		@option_frame = @glade['option_frame']
		
		@option = {}
		@option[@ssh_button] = @glade['ssh_table']
		@option[@socket_button] = @glade['socket_table']
		@option[@net_ssh_button] = @glade['net_ssh_table']
		
		#puts get_active
		redraw_options
		#@window.show
		fill_entries
		
	end
	
	def send_text(text)
		@connection_log.buffer.insert(@connection_log.buffer.end_iter, text+"\n")
	end
	
	def fill_entries
		group = @glade['ssh'].group
		
		group.each do |button|
			@config[button].each do |k, v|
				@glade[button.name+'_'+k].text = v
			end
		end
	end
	
	def get_active
		group = @glade['ssh'].group
		#puts group
		active = nil
		
		group.each do |button|
			if button.active?
				active = button
			end
		end
		
		return active
	end
	
	def redraw_options
		return if !@option_frame
		child = @option_frame.child
		@option_frame.remove(child)
		@option_frame.add(@option[get_active]) if @option
	end
	
	def start_connect
		settings = {}
		
		button = get_active
		@config[button].each do |k, v|
			settings[k] = @glade[button.name+'_'+k].text if @glade[button.name+'_'+k].text.length > 0
		end
		
		method = button.name
		puts method, settings.length
		Thread.new{$main.connect(method, settings)}
		#destroy
	end
	
	def destroy
		@window.destroy
	end
	
	def quit
		destroy
		$main.quit
	end
		
	
end