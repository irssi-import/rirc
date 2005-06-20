class User
	attr_reader :hostname, :name, :lastspoke
	attr_writer :hostname, :lastspoke
	def initialize(name)
		@hostname = nil
		@name = name
		@lastspoke = Time.new
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
	
	def create(name)
		return if self[name]
		new = User.new(name)
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
	
	def sort
		@users.sort!
	end
	
	def length
		return @users.length
	end
end