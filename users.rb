class User
	attr_reader :hostname, :name, :lastspoke
	attr_writer :hostname
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
	end
	
	def lastspoke=(time)
        time = time + $main.drift if $config['canonicaltime'] == 'client'
		@lastspoke = Time.at(time.to_i)
        #puts 'updated lastspoke for '+@name
	end
	
	def comparetostring(string)
	
		a = @name.downcase
		b = string.downcase
		
		return a <=> b
	end
	
end

class UserList < Monitor
	attr_reader :users
	def initialize
		@users = []
        super
	end
	
    def create(name, hostname = nil)
        synchronize do
            do_create(name, hostname)
        end
    end
    
	def do_create(name, hostname = nil)
        return if self[name]
        new = User.new(name)
        new.hostname = hostname
        @users.push(new)
        return new
	end
	
    def add(user)
        synchronize do
            do_add(user)
        end
    end
    
	def do_add(user)
        @users.push(user)
	end
    
    def remove(name)
        synchronize do
            do_remove(name)
        end
    end
    
	def do_remove(name)
        i = 0
        @users.each do |user|
            if user.name == name
                @users.delete_at(i)
                @users.sort!
                return
            end
            i += 1
        end
	end
	
	def[](name)
		result = nil
		@users.each{ |user|
			if user.name == name
				result = user
			end
		}
		return result
	end
	
	def sort!(&block)
        synchronize do
            if block_given?
                @users.sort!(&block)
            else
                @users.sort!
            end
        end
	end
	
	def sort(&block)
        synchronize do
            if block_given?
                return @users.sort(&block)
            else
                return @users.sort
            end
        end
	end
	
	def length
		return @users.length
	end
end