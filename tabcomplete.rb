class TabComplete
	attr_reader :results
	def initialize(substr, list)
		@results = []
		match(substr, list)
		@position = 0
	end
	
	def match(substr, userlist)
		return if substr.length == 0
		userlist.each do |user|
			if user.name[0, substr.length].downcase	== substr.downcase
				@results.push(user)
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
		if !@tabcomplete
            
			if $config['tabcompletesort'] == 'activity'
				#sort by activity
				list = @users.sort{|x, y| y.lastspoke <=> x.lastspoke}
			else	
				#otherwise, sort by name
				list = @users.sort
			end
            
            currentuser = @users[@server.username]
            
            if list.include?(currentuser)
                list.delete(currentuser)
                list.push(currentuser)
            end 
			
			@tabcomplete = TabComplete.new(substr, list)
			if @tabcomplete.firstmatch
				return @tabcomplete.firstmatch.name
			else
				clear_tabcomplete
				return nil
			end
		else
			return @tabcomplete.succ.name
		end
	end
	
	def clear_tabcomplete
		@tabcomplete = nil
	end
end