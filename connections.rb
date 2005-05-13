

class SSHConnection
	def initialize(host)
		@input = nil
		@output = nil
		@error = nil
		@sshthread = Thread.new{
			Net::SSH.start( host ) do |session|
			
			bin = 'irssi2'
			
			if $ssh_binpath
				bin =$ssh_binpath+'/'+bin
			end
		
			@input, @output, @error = session.process.popen3( bin )
			Thread.current['up'] = true
			Thread.current['session'] = session
			session.loop
		end
		}
		while !@sshthread['up']
			#stall until thread is up
		end
		puts 'connected via ssh'
	end
	
	def send(data)
		@input.puts(data)
	end
	
	def listen(object)
		@listenthread = Thread.start{
			while true
				if @output.data_available?
					#puts 'data'
					out = @output.read
					#puts out
					Thread.start{object.parse_lines(out)}
				end
				sleep 1#sleep a little
			end
		}
	end
	
	def close()
	@sshthread['session'].close
	@sshthread.kill
	@input = nil
	@output = nil
	@error = nil
	end
	
end


class UnixSockConnection
	def initialize(file)
		@socket = UNIXSocket.open(file)
		puts 'connected via unix socket'
	end
	
	def send(data)
		@socket.send(data, 0)
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
					#puts input[0, pos]+"---"
					#puts input
				end
			end
			
			rescue SystemCallError
			puts 'Broken Pipe to Irssi'
			@listenthread.kill
			@client = nil
			object.disconnect
			object.connect
		end
		}
	end
	
	def close()
		@socket.close
		@client = nil
	end
	
end