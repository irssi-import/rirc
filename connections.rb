class SSHConnection
	def initialize(settings, connectionwindow)
		require 'open3'
		require 'expect'
		@input = nil
		@output = nil
		@error = nil
		cmdstring = 'setsid ssh '
		cmdstring += '-l '+settings['username']+' ' if settings['username']
		cmdstring += settings['host']+' '+settings['binpath']
		@input, @output, @error = Open3.popen3(cmdstring)

		begin
			@output.expect(/^\*;preauth;time=(\d+)\n/) do |x, y|
				connectionwindow.send_text('logged in')
				$main.calculate_clock_drift(y)
			end
		
		rescue NoMethodError
			connectionwindow.send_text('Something is borked, make sure sshd is running on selected host')
			raise IOError, "one of the many things that could go wrong, has"
		end

	end
	
	def send(data)
		begin
			@input.puts(data)
		#~ rescue SystemCallError
			#~ puts 'Write error: '+$!
			#~ return false
		rescue Errno::EPIPE
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
						#puts 'o: '+line
						object.parse_lines(line)
					end
				
				rescue Errno::EPIPE
					puts 'listen: closed stream, disconnecting '+$!
					close
					object.disconnect
					object.connect
					break
				#~ rescue StandardError
					#~ puts 'listen: closed stream, disconnecting '+$!
					#~ close
					#~ object.disconnect
					#~ object.connect
					#~ break
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

class LocalConnection
	#attr_reader :connected
	def initialize(settings, connectionwindow)
		require 'open3'
		require 'expect'
		@input = nil
		@output = nil
		@error = nil
		@input, @output, @error = Open3.popen3(settings['binpath'])
		begin
			@output.expect(/^\*;preauth;time=(\d+)\n/) do |x, y|
				connectionwindow.send_text('logged in')
				$main.calculate_clock_drift(y)
			end
		
		rescue NoMethodError
			connectionwindow.send_text('Something is borked')
			raise IOError, "one of the many things that could go wrong, has"
		end
	end
	
	def send(data)
		begin
			@input.puts(data)
		#~ rescue SystemCallError
			#~ puts 'Write error: '+$!
			#~ return false
		rescue Errno::EPIPE
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
						#puts 'o: '+line
						object.parse_lines(line)
					end
				
				rescue Errno::EPIPE
					puts 'listen: closed stream, disconnecting '+$!
					close
					object.disconnect
					object.connect
					break
				#~ rescue StandardError
					#~ puts 'listen: closed stream, disconnecting '+$!
					#~ close
					#~ object.disconnect
					#~ object.connect
					#~ break
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
	def initialize(settings, connectionwindow)
		if File.exist?(settings['location'])
			begin
			@socket = UNIXSocket.open(settings['location'])
			rescue
				raise(IOError, 'Error: Could not connect to socket')
			end
			connectionwindow.send_text('Connected via unix socket')
		else
			raise(IOError, 'Socket File does not exist')
		end
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