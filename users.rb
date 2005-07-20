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
        time = time.to_i + $main.drift if $config['canonicaltime'] == 'client'
		@lastspoke = Time.at(time.to_i)
        #puts 'updated lastspoke for '+@name
	end
	
	def comparetostring(string)
	
		a = @name.downcase
		b = string.downcase
		
		return a <=> b
	end
	
end

Modes = {'op' => 2, 'voice'=>1}
Modes.default = 0
ModeSymbols = {'op'=>'@', 'voice'=>'+'}
ModeSymbols.default = ''
SymbolModes = {'@'=> 'op', '+'=>'voice'}
SymbolModes.default = ''

#class that contains a user, as well as channel specific info like modes
class ChannelUser < User
    attr_reader(:modes)
    def initialize(user)
        @user = user
        @modes = []
        #@modes.default = ''
    end
    
    def hostname=(hostname)
        @user.hostname = hostname
    end
    
    def hostname
        return @user.hostname
    end
    
    def name
        return @user.name
    end
    
    def lastspoke
        return @user.lastspoke
    end
    
    def lastspoke=(time)
        @user.lastspoke(time)
    end
    
    def <=>(object)
        #puts self, object
        #puts @modes, object.modes
        res = object.get_modenumber<=>get_modenumber
        if res == 0
            res = @user<=>(object)
        end
        #puts 'returning '+res.to_s+'for <=>'
        return res
    end
    
    def comparetostring(string, mode)
        #puts 'comparing '+string+' '+mode
        #puts 'to '+name+' '+get_modes
        #puts decodemode(mode), get_modenumber
        res = decodemode(mode)<=>get_modenumber
        if res == 0
            #puts 'going down the stack'
            res = @user.comparetostring(string)
        end
        return res
    end
    
    def decodemode(mode)
        if mode.class == Fixnum
            mode = mode.chr
        end
        #return ModeSymbol[mode]
        modenumber = 0
        mode.each_byte do |b|
            modenumber += mode2int(SymbolModes[b.chr])
            #puts b.chr+'has a value of '+SymbolModes[b.chr]+'=>'+mode2int(SymbolModes[b.chr]).to_s
        end
        return modenumber
    end
    
    def get_modenumber
        modenumber = 0
        @modes.each do |mode|
            modenumber += mode2int(mode)
        end
        return modenumber
    end
    
    def get_modes
        #puts ModeSymbols
        modestring = ''
        @modes.each do |mode|
            modestring += ModeSymbols[mode]
        end
        return modestring
        #return SymbolMode[@mode]
    end
    
    def get_mode
        return ModeSymbols[@modes[-1]]
    end
    
    #convert to int for easy comparison
    def mode2int(mode)
        return Modes[mode]
    end
    
    def add_mode(mode)
        @modes[mode2int(mode)] = mode 
        #puts 'mode set to '+@mode.to_s
        #puts 'Added mode '+mode
        #puts get_modenumber
    end
    
    def remove_mode(mode)
        @modes.delete_at(mode2int(mode))
        #puts 'Removed mode '+mode
        #puts get_modenumber
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

class ChannelUserList < UserList
    def add(user)
        synchronize do
            return do_add(ChannelUser.new(user))
        end
    end
    
	def do_add(user)
        @users.push(user)
        return user
	end
end