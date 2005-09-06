class ConnectionWindow
	attr_reader :autoconnect
	def initialize
		require 'yaml'
		@glade = GladeXML.new("glade/connect.glade") {|handler| method(handler)}
		@window = @glade['window1']
		
		@connection_log = @glade['connection_log']
		
        @local_button = @glade['local'] 
		@ssh_button = @glade['ssh']
		@socket_button = @glade['socket'] 
		@net_ssh_button = @glade['net_ssh']
		@net_ssh_button.sensitive = false
        @socket_button.sensitive = false
        @net_ssh_button.sensitive = $netssh
		if $platform == 'win32'
			@local_button.sensitive = false
		end
		
		#@ssh_button.active = true
		@config = {}
		
		@config['default_method'] = 'local'
		
		@config[@ssh_button] = {}
		@config[@ssh_button]['host'] = 'localhost'
		if $platform == 'linux'
			@config[@ssh_button]['username'] = `whoami`.chomp
		else
			@config[@ssh_button]['username'] = 'irssi2'
		end
		@config[@ssh_button]['binpath'] = '/usr/bin/irssi2'
        @config[@ssh_button]['port'] = '22'
		
        @config[@local_button] = {}
        @config[@local_button] ['binpath'] = '/usr/bin/irssi2'
        
		@config[@socket_button] = {}
		if $platform == 'linux'
			@config[@socket_button]['location'] = ENV['HOME']+'/.irssi2/client-listener'
		elsif $platform == 'win32'
			@config[@socket_button]['location'] = ''
		end
		
		@config[@net_ssh_button] = {}
        @config[@net_ssh_button] ['host'] = 'localhost'
		if $platform == 'linux'
			@config[@net_ssh_button]['username'] = `whoami`.chomp
		else
			@config[@net_ssh_button]['username'] = 'irssi2'
		end
		
		@option_frame = @glade['option_frame']
		
		@option = {}
		@option[@ssh_button] = @glade['ssh_table']
		@option[@socket_button] = @glade['socket_table']
		@option[@net_ssh_button] = @glade['net_ssh_table']
        @option[@local_button] = @glade['local_table']
		
		redraw_options
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

		unless File.directory?($rircfolder)
            Dir.mkdir($rircfolder)
        end
		File.open($rircfolder+'/settings.yaml', "w") {|f| YAML.dump(settings, f)}
	end
	
	def load_settings
		return if !File.exists?($rircfolder+'/settings.yaml')
		settings = YAML.load_file($rircfolder+'/settings.yaml')
		
		group = @glade['ssh'].group
		group.each do |button|
			if settings[button.name]
				@config[button].merge!(settings[button.name])
			end
		end
		
		settings.each do |k, v|
			if v.class != Hash
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
		false
	end
		
	
end