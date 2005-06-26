class User
	attr_reader :hostname, :name, :lastspoke
	attr_writer :hostname#, :lastspoke
	def initialize(name)
		@hostname = nil
		@name = name
		time = Time.new
		time = time - $main.drift if $config['canonicaltime'] == 'server'
		@lastspoke = time
	end
	
	def rename(name)
		@name = name
	end
	
	def <=>(object)
		a = @name.downcase
		b = object.name.downcase
		
		return a <=> b
		#~ length = @name.length
		#~ retval =-1
		#~ if object.name.length < @name.length
			#~ length = object.name.length
			#~ retval = 1
		#~ end
		
		#~ for i in 0...(length)
			#~ if @name[i] > object.name[i]
				#~ #puts @name+' > '+object.name
				#~ return 1
			#~ elsif @name[i] < object.name[i]
				#~ #puts @name+' < '+object.name
				#~ return -1
			#~ end
		#~ end
		#~ return retval
	end
	
	def lastspoke=(time)
		@lastspoke = Time.at(time.to_i)
	end
	
	def comparetostring(string)
	
		a = @name.downcase
		b = string.downcase
		
		return a <=> b
		#~ orig = @name.deep_clone
		
		#~ if string == orig
			#~ return 0
		#~ end
		
		#~ length = orig.length
		#~ retval =-1
		#~ if string.length < orig.length
			#~ length = string.length
			#~ retval = 1
		#~ end
		
		#~ for i in 0...(length)
			#~ if orig[i] > string[i]
				#~ #puts @name+' > '+object.name
				#~ return 1
			#~ elsif orig[i] < string[i]
				#~ #puts @name+' < '+object.name
				#~ return -1
			#~ end
		#~ end
		#~ return retval
	end
	
end

class UserList
	attr_reader :users
	def initialize
		@users = []
	end
	
	def create(name, hostname = nil)
		return if self[name]
		new = User.new(name)
		new.hostname = hostname
		@users.push(new)
		@users.sort!
		#puts 'creating user: ' +name
		#puts @users.length
		return new
	end
	
	def add(user)
		@users.push(user)
		@users.sort!
	end
	def remove(name)
		i = 0
		@users.each{ |user|
			if user.name == name
				#puts @users.length.to_s
				@users.delete_at(i)
				#puts 'removed at ' +i.to_s
				#puts @users.length.to_s
				@users.sort!
				return
			end
			i += 1
		}
	end
	
	def[](name)
		result = nil
		@users.each{ |user|
			if user.name == name
				#puts 'matched ' +name
				result = user
			end
		}
		return result
	end
	
	def sort!(&block)
		if block_given?
			@users.sort!(&block)
		else
			@users.sort!
		end
	end
	
	def sort(&block)
		if block_given?
			return @users.sort(&block)
		else
			return @users.sort
		end
	end
	
	def length
		return @users.length
	end
end