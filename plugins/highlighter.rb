class Highlighter < Plugin
    attr_accessor :terms
    def load
        $config.set_value('highlightstrings', []) unless $config['highlightstrings']
        $config.set_value('highlightplugincolor', Gdk::Color.new(65535, 65535, 0)) unless $config['highlightplugincolor']
        
        #/add_highlight adds a highlight
        add_method(self, Main, 'cmd_add_highlight') do |args, channel, network, presence|
        
            unless $config['highlightstrings'].include?(args)
                puts 'added highlight for '+args
                $config['highlightstrings'].push(args)
            end
            
            $config['highlightstrings'].sort! {|x, y| y.length<=>x.length}
            
        end
        
        #/del_highlight removes a highlight
        add_method(self, Main, 'cmd_del_highlight') do |args, channel, network, presence|
        
            if $config['highlightstrings'].include?(args)
                puts 'removed highlight for '+args
                $config['highlightstrings'].delete(args)
            end
        end
        
        #/highlights lists defined highlights
        add_method(self, Main, 'cmd_highlights') do |args, channel, network, presence|
            
            lines = ['Defined Highlights:']
            
            $config['highlightstrings'].each {|term| lines.push(term)}
            
            lines.push(' ')
            
            lines.each do |line|
                event = {'msg' => line}
                @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
            end
        end
    
        add_callback_after(self, Buffer, 'buffer_message') do |local, uname, pattern, users, insert_location|
            #puts uname, pattern, users, insert_location
        
            replace = false
            replacements = []
            
            $config['highlightstrings'].each do |term|
                
                if pattern.include?(term)
                    exists = false
                    replacements.each do |s|
                        exists = true if s.include?(term)
                    end
                    unless exists
                        replace = true
                        replacements.push(term)
                        color = $config['highlightplugincolor'].to_hex
                        pattern.gsub!(term, '<span color="'+color+'">'+term+'</span>')#you can change the highlight color here...
                    end
                end
            end
            
            if replace
                if insert_location == BUFFER_END
                    `beep`
                    local.setstatus(HIGHLIGHT)
                end
            end
            
            [uname, pattern, users, insert_location]
        end
    end
    
    def configure
        value = $config['highlightplugincolor']
        value ||= Gdk::Color.new(65535, 65535, 0)
        return [{'type' => Gdk::Color, 'name' => 'highlightplugincolor',
        'value' => value, 'description' => 'Highlight Color'},
        {'type' => Array, 'name' => 'highlightstrings', 
        'value' => $config['highlightstrings'], 'description' => 'Strings to highlight',
        'tooltip' => 'CSV list of strings to highlight'}]
    end
end

highlighter = Highlighter.new
Plugin.register(highlighter)