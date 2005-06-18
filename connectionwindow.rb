class ConnectionWindow
	attr_reader :autoconnect
	def initialize
		require 'yaml'
		@glade = GladeXML.new("glade/connect.glade") {|handler| method(handler)}
		@window = @glade['window1']
		
		@connection_log = @glade['connection_log']
		
		@ssh_button = @glade['ssh']
		@socket_button = @glade['socket'] 
		@net_ssh_button = @glade['net_ssh']
		@net_ssh_button.sensitive = false
		
		#@ssh_button.active = true
		@config = {}
		
		@config['default_method'] = 'socket'
		
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
		load_settings
		@glade[@config['default_method']].active = true
		fill_entries
		@autoconnect = @config['autoconnect']
	end
	
	def save_settings
		get_config
		settings = { 'default_method' => get_active.name, 
					'autoconnect' => @glade['autoconnect'].active?}
					#~ 'ssh' => {},
					#~ 'socket' => {},
					#~ 'net_ssh' => {}
				#~ }
				
		group = @glade['ssh'].group
		
		group.each do |button|
			@config[button].each do |k, v|
				if v.length > 0
					settings[button.name] = {} if !settings[button.name]
					settings[button.name][k] = v
				end
			end
		end
		
		puts settings['ssh'].length, 'Items'
		
		File.open('settings.yaml', "w") {|f| YAML.dump(settings, f)}
	end
	
	def load_settings
		return if !File.exists?('settings.yaml')
		settings = YAML.load(File.open('settings.yaml'))
		
		group = @glade['ssh'].group
		group.each do |button|
			if settings[button.name]
				@config[button] = settings[button.name]
			end
		end
		
		settings.each do |k, v|
			if v.class != Hash
				puts k, v
				@config[k] = v
			end
		end
	end
	
	def get_config
		group = @glade['ssh'].group
		
		group.each do |button|
			@config[button].each do |k, v|
				@config[button][k] = @glade[button.name+'_'+k].text if @glade[button.name+'_'+k]
			end
		end
	end
	
	def send_text(text)
		@connection_log.buffer.insert(@connection_log.buffer.end_iter, text+"\n")
	end
	
	def fill_entries
		group = @glade['ssh'].group
		
		group.each do |button|
			@config[button].each do |k, v|
				@glade[button.name+'_'+k].text = v if @glade[button.name+'_'+k]
			end
		end
		
		@glade['autoconnect'].active = @config['autoconnect']
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
		save_settings
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