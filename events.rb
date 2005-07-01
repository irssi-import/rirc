class Event
	attr_reader :complete, :lines, :name, :command, :origcommand
	def initialize(name, command)
		@name = name
		@lines = []
		@complete = false
		@command = {}
		@origcommand = command
		parsecommand(command)
	end
	
	#get the info of the original command
	def parsecommand(command)
		attribs = command.split(';')
		
		@command['command'] = attribs[0]
		
		attribs.each do |x|
			vals = x.split('=', 2)
			if vals[1] and vals[1] != ''
				vals[1].gsub!('\\\\.', ';')
				vals[1].gsub!('\\.', ';')
				vals[1].gsub!('\\\\\\\\', '\\')
				@command[vals[0]] = vals[1]
			elsif x.count('=') == 0
				@command[x] = true
			end
		end
	end
	
	#parse a line and add it to the object
	def addline(line)
		temp = {}
		vars = line.split(";", 3)
		temp['tagname'] = vars[0]
		temp['status'] = vars[1]
		temp['original'] = line
		
		if !vars[2]
			lines.push(temp)
			#puts'no other info '+line
			break
		end
		
		items = vars[2].split(';')
		
		items.each do |x|
			vals = x.split('=', 2)
			if vals[1] and vals[1] != ''
                #puts vals[1]
				vals[1].gsub!('\\\\.', ';')
				vals[1].gsub!('\\.', ';')
				vals[1].gsub!('\\\\\\\\', '\\')
				temp[vals[0]] = vals[1]
			elsif x.count('=') == 0
				temp[x] = true
			end
		end
		
		if @command['command'] != 'event get'
			$main.calculate_clock_drift(temp['time'])
		end
		
		if $config['canonicaltime'] == 'client'
			temp['time'] = Time.at(temp['time'].to_i + $main.drift)
		end
		
		if temp['status'] == '+'
			@complete = true
		end
		
		if temp['status'] == '-'
			error = line.gsub(temp['tagname']+';-;', '')
			temp['error'] = error
			@complete = true
		end
		
		@lines.push(temp)
	end
end