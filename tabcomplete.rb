#~ require('users')

#~ userlist = UserList.new

#~ names = ['AArdvark', 'Beta', 'Dude', 'vapid', 'Vagabond', 'vag', 'alpha', 'damn']

#~ names.each do |name|
	#~ userlist.create(name)
#~ end

#~ userlist['Vagabond'].lastspoke = Time.at(0)
#~ #puts userlist['Vagabond'].lastspoke
#~ list = userlist.sort {|x, y| y.lastspoke <=> x.lastspoke}

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
				#puts user.name+' matches '+substr
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

#~ bleh = TabComplete.new('va', list)
#~ bleh.results.each do |user|
	#~ puts user.name
#~ end
#~ puts bleh.firstmatch.name
#~ puts bleh.succ.name
#~ puts bleh.succ.name
#~ puts bleh.succ.name