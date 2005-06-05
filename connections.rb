class SSHConnection
	def initialize(host)
		require 'open3'
		require 'expect'
		@input = nil
		@output = nil
		@error = nil
		puts 'connecting'
		@input, @output, @error = Open3.popen3("setsid ssh "+host+' '+$ssh_binpath)
		#puts 'connected'
		#puts @output.gets
		#sleep 5
		#loop { puts @output.gets }
		begin
			@output.expect(/^\*:preauth:time=\d*$/) do
				puts 'logged in'
			end
		
		rescue NoMethodError
			puts 'Something is borked, make sure sshd is running on selected host'
		end
	end
	
	def send(data)
		begin
			@input.puts(data)
		rescue SystemCallError
			puts 'Write error: '+$!
			return false
		rescue IOError
			puts 'Write error: '+$!
			return false
		end
		return true
	end
	
	def listen(object)
		@listenthread = Thread.new do
			loop do
				begin
					while line = @output.gets
						object.parse_lines(line)
					end
				
				rescue IOError
					puts 'listen: closed stream, disconnecting '+$!
					close
					object.disconnect
					object.connect
					break
				rescue StandardError
					puts 'listen: closed stream, disconnecting '+$!
					close
					object.disconnect
					object.connect
					break
				end
			end
		end
	end
	
	def close
		@listenthread.kill if @listenthread
		@input.close
		@output.close
		@error.close
	end
end

#~ class RbSSHConnection
	#~ def initialize(host)
		#~ @input = nil
		#~ @output = nil
		#~ @error = nil
		
		#~ options = {}
		
		#~ options[:keys] = $ssh_keys if $ssh_keys
		
		#~ options[:compression] = $ssh_compression if $ssh_compression
		
		#~ options[:username] = $ssh_username if $ssh_username
		
		#~ options[:password] = $ssh_password if $ssh_password
		
		#~ #begin
		#~ @session = Net::SSH.start(host, options)
		#~ #rescue StandardError
		#~ #	puts 'error '+$!
		#~ #	return false
		#~ #end
		
		#~ @input, @output, @error = @session.process.popen3( $ssh_binpath )
		#~ sleep 2
		#~ if @error.data_available?
			#~ error = 'ERROR: ' + @error.read
			#~ raise(IOError, error, caller)
			#~ #return false
		#~ end
		
		#~ puts @error.gets
		
		#~ @sshthread = Thread.new{
			#~ #Net::SSH.start( host ) do |session|
			#~ #Thread.current['up'] = true
			#~ #Thread.current['session'] = session
			#~ @session.loop
		#~ #end
		#~ }
		#~ #while !@sshthread['up']
			#~ #stall until thread is up
		#~ #end
		#~ puts 'connected via ssh'
	#~ end
	
	#~ def send(data)
		#~ begin
		#~ @input.puts(data)
		#~ rescue IOError
			#~ puts 'closed stream, disconnecting '+$!
			#~ close
			#~ return false
		#~ rescue StandardError
			#~ puts 'closed stream, disconnecting '+$!
			#~ close
			#~ return false
		#~ end
		#~ return true
	#~ end
	
	#~ def listen(object)
		#~ @listenthread = Thread.start{
			#~ while true
				#~ begin
				#~ if @output.data_available?
					#~ #puts 'data'
					#~ out = @output.read
					#~ #puts out
					#~ Thread.start{object.parse_lines(out)}
				#~ end
				#~ sleep 1#sleep a little
				#~ rescue IOError
					#~ puts 'listen: closed stream, disconnecting '+$!
					#~ close
					#~ object.disconnect
					#~ object.connect
					#~ break
				#~ rescue StandardError
					#~ puts 'listen: closed stream, disconnecting '+$!
					#~ close
					#~ object.disconnect
					#~ object.connect
					#~ break
				#~ end
			#~ end
		#~ }
	#~ end
	
	#~ def close
	#~ @session.close if @session
	#~ @sshthread.kill if @sshthread
	#~ @input = nil
	#~ @output = nil
	#~ @error = nil
	#~ end
	
#~ end


class UnixSockConnection
	def initialize(file)
		begin
		@socket = UNIXSocket.open(file)
		rescue
			raise(IOError, 'Error: Could not connect to socket '+file, caller)
		end
		puts 'connected via unix socket'
	end
	
	def send(data)
		begin
		@socket.send(data, 0)
		rescue SystemCallError
			puts 'Broken Pipe to Irssi, disconnecting '+$!
			close
			return false
		end
		return true
	end

	def listen(object)
		@listenthread = Thread.start{
			input = ''
			begin
			while line = @socket.recv(70)
				if line.length == 0
					sleep 1
				end
				input += line
				if input.count("\n") > 0
					pos = input.rindex("\n")
					string = input[0, pos]
					input = input[pos, input.length]
					Thread.start{
						object.parse_lines(string)
					}
				end
			end
			
			rescue SystemCallError
			puts 'Broken Pipe to Irssi, disconnecting '+$!
			close
		end
		}
	end
	
	def close
		@listenthread.kill
		@socket.close
		@client = nil
	end
	
end