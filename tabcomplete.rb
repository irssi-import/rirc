class TabComplete
    attr_reader :results
    def initialize(substr, list)
        @results = []
        match(substr, list)
        @position = 0
    end
    
    def match(substr, list)
        return if substr.length == 0
        list.each do |item|
            if item[0, substr.length].downcase == substr.downcase
                @results.push(item)
            end
        end
    end
    
    def firstmatch
        return @results[0]
    end
    
    def succ
        @position += 1
        @position = 0 if @position >= @results.length
        return @results[@position]
    end
end

#mixin for adding to buffers
module TabCompleteModule
    def tabcomplete(substr)
#         puts self
        if !@tabcomplete
            if substr[0].chr == '/'
                list = @main.command_list
            elsif self.respond_to? :users and  !self.network != self
                puts self
                if @config['tabcompletesort'] == 'activity'
                    #sort by activity
                    list = @users.users.sort{|x, y| y.lastspoke <=> x.lastspoke}
                else	
                    #otherwise, sort by name
                    list = @users.users.sort
                end
                
                currentuser = @users[username]
                
                if list.include?(currentuser)
                    list.delete(currentuser)
                    list.push(currentuser)
                end
                list = list.map{|x| x.name}
            else
                return nil
            end
            
            @tabcomplete = TabComplete.new(substr, list)
            if @tabcomplete.firstmatch
                return @tabcomplete.firstmatch
            else
                clear_tabcomplete
                return nil
            end
        else
            return @tabcomplete.succ
        end
    end
    
    def clear_tabcomplete
        @tabcomplete = nil
    end
end
