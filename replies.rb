class Reply
    attr_reader :complete, :lines, :name, :command, :origcommand, :error, :network, :channel, :start, :retries
    attr_writer :retries
    attr_accessor :lineref, :network, :presence, :channel
    
    def initialize(main, name, command)
        @main = main
        @start = Time.new
        @name = name
        @lines = []
        @complete = false
        @command = {}
        @error = false
        @origcommand = command
        parsecommand(command)
        @network = nil
        @channel = nil
        @presence = nil
        @retries = 0
    end
	
    #get the info of the original command
    def parsecommand(command)
        attribs = command.split(';')
        
        @command['command'] = attribs[0]
            
        attribs.each do |x|
            vals = x.split('=', 2)
            if vals[1] and vals[1] != ''
                #unescape the original command values
                vals[1].gsub!('\\\\.', ';')
                vals[1].gsub!('\\.', ';')
                vals[1].gsub!('\\\\\\\\', '\\')
                @command[vals[0].to_sym] = vals[1]
            elsif x.count('=') == 0
                @command[x.to_sym] = true
            end
        end
    end
    
    #parse a line and add it to the reply object
    def addline(line)
        #time = Time.new
        temp = Line.new
        vars = line.split(";", 3)
        temp['tagname'] = vars[0]
        temp[:reply_status] = vars[1]
        temp['original'] = line
        
        if !vars[2]
                lines.push(temp)
                break
        end
        
        items = vars[2].split(';')
        
        items.each do |x|
            vals = x.split('=', 2)
            if vals[1] and vals[1] != ''
                #unescape the reply values
                vals[1].gsub!("\\.", "\\\\.")
                vals[1].gsub!(%r{\\{1}\\\.}, '!.')
                vals[1].gsub!('\\.', ';')
                vals[1].gsub!('!.', '\\.')
                vals[1].gsub!('\\\\', '\\')
                temp[vals[0].to_sym] = vals[1]
            elsif x.count('=') == 0
                temp[x.to_sym] = true
            end
        end
        
        if @command['command'] != 'event get'
            @main.calculate_clock_drift(temp['time'])
        end
        
        if @main.config['canonicaltime'] == 'client'
            begin
                temp['time'] = Time.at(temp['time'].to_i + @main.drift)
            rescue RangeError
                puts "#{temp['time']} is too large"
                puts line
            end
        end
        
        if temp[:reply_status] == '+'
            @complete = true
        end
        
        if temp[:reply_status] == '-'
            error = line.gsub(temp['tagname']+';-;', '')
            temp[:error] = error
            @complete = true
            @error = true
        end
        
        @lines.push(temp)
        #finish if @complete
    end
    
    def finish
        #@lines.sort!{|x, y| x[ID] <=> y[ID]}
        #@lines.sort!{|x, y| x[TIME].to_i <=> y[TIME].to_i}
        @lines = @lines.sort_by {|l| [l[ID], l[TIME].to_i]}
        #@complete = true
    end
end
