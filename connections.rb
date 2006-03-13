class Connection
	def listen(object)
		@listenthread = Thread.new do
			loop do
				begin
					if res = select([@output], nil, nil, nil) and res[0]
						line = res[0][0].gets
						@main.parse_line(line.chomp) if line
					end
				end
			end
		end
	end

	def send(data)
		begin
			@input.puts(data)
		rescue Errno::EPIPE
			puts 'Write error: '+$!
			return false
		end
		return true
	end
end
class SSHConnection < Connection
	def initialize(main, settings, connectionwindow)
		@main = main
		require 'open3'
		require 'expect'
		@input = nil
		@output = nil
		@error = nil
		cmdstring = 'setsid ssh '
		cmdstring += '-l '+settings['username']+' ' if settings['username']
		cmdstring += '-p '+settings['port']+' ' if settings['port']
		cmdstring += settings['host']+' '+settings['binpath']
#         puts cmdstring
		@input, @output, @error = Open3.popen3(cmdstring)
		#puts @output.gets

		begin
			@output.expect(/^\*;preauth;time=(\d+);$/) do |x, y|
				connectionwindow.send_text('logged in')
				@main.calculate_clock_drift(y)
			end

		rescue NoMethodError
			connectionwindow.send_text('Something is borked, make sure sshd is running on selected host')
			raise IOError, "one of the many things that could go wrong, has"
		end

	end

	#     def send(data)
	#         begin
	#             @input.puts(data)
	#             #~ rescue SystemCallError
	#             #~ puts 'Write error: '+$!
	#             #~ return false
	#         rescue Errno::EPIPE
	#             puts 'Write error: '+$!
	#             return false
	#         end
	#         return true
	#     end

	#     def listen(object)
	#         @listenthread = Thread.new do
	#             loop do
	#                 begin
	#                     while line = @output.gets
	#                         #puts 'o: '+line
	#                         object.parse_lines(line)
	#                     end

	#                 rescue Errno::EPIPE
	#                     puts 'listen: closed stream, disconnecting '+$!
	#                     close
	#                     object.disconnect
	#                     object.connect
	#                     break
	#                 end
	#             end
	#         end
	#     end

	def close
		@listenthread.kill if @listenthread
		@input.close
		@output.close
		@error.close
	end
end

class LocalConnection < Connection
	#attr_reader :connected
	def initialize(main, settings, connectionwindow)
		require 'open3'
		require 'expect'
		@main = main
		@input = nil
		@output = nil
		@error = nil
		if settings['binpath'][0].chr == '/'
			unless File.exists? settings['binpath']
				raise IOError, "Cannot find binary at #{settings['binpath']}"
			end
		elsif settings['binpath'].include? '/'
			path = Pathname.new(settings['binpath'])
			unless path.file?
				raise IOError, "Cannot find binary at #{path.realpath}"
			end
		else
			exists = false
			ENV['PATH'].split(':').each do |d| #: is not windows compatible, but that's not really relevant
				#                 puts d
				if File.exists? d+'/'+settings['binpath']
					exists = true
					break
				end
			end
			unless exists
				raise IOError, "Cannot find binary #{settings['binpath']} in $PATH"
			end
		end
		@input, @output, @error = Open3.popen3(settings['binpath'])
		begin
			@output.expect(/^\*;preauth;time=(\d+);\n/) do |x, y|
				connectionwindow.send_text('logged in')
				@main.calculate_clock_drift(y)
			end

		rescue NoMethodError
			connectionwindow.send_text('Something is borked')
			raise IOError, "one of the many things that could go wrong, has"
		end
	end

	#     def send(data)
	#         begin
	#             @input.puts(data)
	#         rescue Errno::EPIPE
	#             puts 'Write error: '+$!
	#             return false
	#         end
	#         true
	#     end

	#     def listen(object)
	#         @listenthread = Thread.new do
	#             loop do
	#                                 puts 'bar'
	#                 begin
	#                                         while line = @output.gets
	#puts 'o: '+line
	#                                             object.parse_lines(line)
	#                                         end
	#                     if res = select([@output], nil, nil, nil) and res[0]
	#                                                 puts res[0].inspect
	#                                                 puts res[0][0].read.class
	#                         @main.parse_line(res[0][0].gets.chomp)

	#                         #Thread.new do
	#                                                     @main.parse_lines(res[0][0].readlines("\n"))
	#                         #end
	#                     else
	#                         puts 'no IO'
	#                     end
	#                                     rescue Errno::EPIPE
	#                                         puts 'listen: closed stream, disconnecting '+$!
	#                                         close
	#                                         object.disconnect
	#                                         object.connect
	#                                         break
	#                 end
	#             end
	#         end
	#     end

	def close
		@listenthread.kill if @listenthread
		@input.close
		@output.close
		@error.close
	end
end

class NetSSHConnection < Connection
	def initialize(main, settings, connectionwindow)
		@main = main
		begin
			@session = Net::SSH.start(settings['host'], settings['username'], :auth_methods => %w(password), :port => settings['port'])

			@input, @output, @error = @session.process.popen3(settings['binpath'])

		rescue Errno::EHOSTUNREACH
			raise(IOError, 'Could not connect to host')
		rescue Net::SSH::AuthenticationFailed
			raise(IOError, 'Authentication Failed')
		rescue Errno::ECONNREFUSED
			raise(IOError, 'Connection Refused')
		end
		sleep 2
		if @error.data_available?
			error = @error.read
			raise(IOError, error, caller)
		end

		#@sshthread = Thread.new{
		#	@session.loop
		#}
		puts 'connected via ssh'
	end

	def send(data)
		begin
			@input.puts(data)
		rescue Errno::EPIPE
			puts 'Write error: '+$!
			return false
		end
		return true
	end

	def listen(object)
		@listenthread = Thread.start do
			while true
				begin
					if @output.data_available?
						out = @output.read
						object.parse_lines(out)
					end
					sleep 0.01#sleep a little, this seems to be important
				rescue IOError
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
		@session.close if @session
		@sshthread.kill if @sshthread
		@input = nil
		@output = nil
		@error = nil
	end

end


class UnixSockConnection < Connection
	def initialize(settings, connectionwindow)
		if File.exist?(settings['location'])
			begin
				@socket = UNIXSocket.open(settings['location'])
			rescue
				raise(IOError, 'Could not connect to socket')
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


class InetdConnection < Connection
	def initialize(main, settings, connectionwindow)
		@main = main
		begin
			@socket = TCPSocket.new(settings['host'], settings['port'].to_i)
		rescue
			raise(IOError, 'Could not connect to socket')
		end
		connectionwindow.send_text('Connected via TCP socket')
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
			loop do
			if res = select([@socket], nil, nil, nil) and res[0]
				@main.parse_line(res[0][0].gets.chomp)
			end
			end
			#~ input = ''
			#~ begin
			#~ while line = @socket.recv(70)
			#~ if line.length == 0
			#~ sleep 1
			#~ end
			#~ input += line
			#~ if input.count("\n") > 0
			#~ pos = input.rindex("\n")
			#~ string = input[0, pos]
			#~ input = input[pos, input.length]
			#~ Thread.start{
			#~ object.parse_lines(string)
			#~ }
			#~ end
			#~ end

			#~ rescue SystemCallError
			#~ puts 'Broken Pipe to Irssi, disconnecting '+$!
			#~ close
			#~ end
		}
	end

	def close
		@listenthread.kill
		@socket.close
		@client = nil
	end

end

class ConnectionFactory

	# Create a class variable constant of the various available connection
	# types.

	Types = {
		"ssh" => SSHConnection,
		"socket" => UnixSockConnection,
		"inetd" => InetdConnection,
		"local" => LocalConnection,
		"net_ssh" => NetSSHConnection }

	def self.spawn( type, *params )
		object = Types[type]
		unless object
			raise( ArgumentError, "Supplied connection type \"" + type + "\" is not available." )
		end
		return object.new( *params )
	end

end
