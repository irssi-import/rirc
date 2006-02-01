class User
    attr_reader :hostname, :name, :lastspoke
    attr_writer :hostname
    def initialize(name)
        @hostname = nil
        @name = name
        time = Time.new
        #time = time - $main.drift if $config['canonicaltime'] == 'server'
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
        #time = time.to_i + $main.drift if $config['canonicaltime'] == 'client'
        @lastspoke = Time.at(time.to_i)
    end
    
    def comparetostring(string)
        a = @name.downcase
        b = string.downcase
        
        return a <=> b
    end
end

#class that contains a user, as well as channel specific info like modes
class ChannelUser < User
    Modes = ['', 'voice', 'op'].reverse
    #Modes = {'op' => 2, 'voice'=>1}
    #Modes.default = 0
    ModeSymbols = {'op'=>'@', 'voice'=>'+'}
    ModeSymbols.default = ''
    #SymbolModes = {'@'=> 'op', '+'=>'voice'}
    #SymbolModes.default = ''
    attr_reader :mode
    def initialize(user)
        @user = user
        @mode = ''
    end
    
    def hostname=(hostname)
        @user.hostname = hostname
    end
    
    def hostname
        @user.hostname
    end
    
    def name
        @user.name
    end
    
    def lastspoke
        @user.lastspoke
    end
    
    def lastspoke=(time)
        @user.lastspoke(time)
    end
    
    def mode_symbol
        ModeSymbols[mode]
    end
    
    def mode=(mode)
        mode ||= ''
        @mode = mode
    end
end

class UserList
    attr_reader :users
    def initialize
        @users = []
        super
    end
    
    def create(name, hostname = nil)
        return if self.include?(name)
        new = User.new(name)
        new.hostname = hostname
        @users.push(new)
        return new
    end
	
    def add(user)
        return if self.include?(user)
        @users.push(user)
    end
    
    def include?(newuser)
        if newuser.respond_to? :name
            @users.each do |user|
                if user.name == newuser.name
                    return true
                end
            end
        elsif newuser
            @users.each do |user|
                if user.name == newuser
                    return true
                end
            end
        end
        return false
    end
    
    def remove(name)
    i = 0
    @users.each do |user|
        if user.name == name
            @users.delete_at(i)
            #@users.sort!
            return
        end
        i += 1
    end
    end
    
    def[](name)
        result = nil
        @users.each do |user|
            if (user.respond_to? :name and user.name == name)
                result = user
            end
        end
        return result
    end
    
    def length
        @users.length
    end
end

class ChannelUserList < UserList
    attr_accessor :view
    def include?(newuser)
        if newuser.class == ChannelUser
            @users.each do |user|
                if user.name == newuser.name
                    return true
                end
            end
        else
            @users.each do |user|
                if user.name == newuser
                    return true
                end
            end
        end
        false
    end

    def summarize
        opcount = @users.select{|x| x.mode == 'op'}.to_a.length
        voicecount = @users.select{|x| x.mode == 'voice'}.to_a.length
        total = @users.length
        "#{opcount.to_s+' ops, ' if opcount > 0}#{voicecount.to_s+' voiced, ' if voicecount > 0}#{total} total"
    end
    
    def remove(user)
        super
        @view.remove_user(user) if @view
        @view.summary = summarize if @view
    end
    
    def add(user, sync=true)
        user = ChannelUser.new(user)
        return user if self.include?(user)
        @users.push(user)
        if sync
            sort
            @view.add_user(user, @users.index(user)) if @view
            @view.summary = summarize if @view
        end
        user
    end
    
    def reorder(user)
        #~ @view.update(@users.index(user), user)
        #~ oldusers = @users.dup
        oldposition = @users.index(user)
        sort
        newposition = @users.index(user)
        #~ order = @users.map{|x| oldusers.index(x)}
        @view.reorder(oldposition, newposition, user) if @view
        @view.summary = summarize if @view
    end
    
    def fill_view
        @view.fill(self) if @view
        @view.summary = summarize if @view
    end
    
    def sort
#         puts 'sorting'
        @users = @users.sort_by{|x| [ChannelUser::Modes.index(x.mode), x.name.downcase]}
        #puts @users.inspect
    end
end
