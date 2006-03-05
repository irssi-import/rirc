# a highlighter plugin

class Highlighter < Plugin
    attr_accessor :terms
    def load
        @@main.config['highlightstrings'] ||= []
        @@main.config['highlightplugincolor'] ||= Color.new(65535, 65535, 0)
        @@main.config['highlightcommand'] ||= 'none'

        #/add_highlight adds a highlight
        help :cmd_add_highlight, "Add a highlight string"
        add_method(self, Main, 'cmd_add_highlight') do |args, target|

            unless @@main.config['highlightstrings'].include?(args)
                puts 'added highlight for '+args
                @@main.config['highlightstrings'].push(args)
            end

            @@main.config['highlightstrings'].sort! {|x, y| y.length<=>x.length}

        end

        #/del_highlight removes a highlight
        help :cmd_del_highlight, "Delete a highlight string"
        add_method(self, Main, 'cmd_del_highlight') do |args, target|

            if @@main.config['highlightstrings'].include?(args)
                puts 'removed highlight for '+args
                @@main.config['highlightstrings'].delete(args)
            end
        end

        #/highlights lists defined highlights
        help :cmd_highlights, "List all highlight strings"
        add_method(self, Main, 'cmd_highlights') do |args, target|

            lines = ['Defined Highlights:']

            @@main.config['highlightstrings'].each {|term| lines.push(term)}

            lines.push(' ')

            lines.each do |line|
                event = {'msg' => line}
                @window.currentbuffer.send_user_event(event, EVENT_NOTICE)
            end
        end

        add_callback_after(self, Buffer, 'buffer_message') do |uname, pattern, users, insert_location|
            #puts uname, pattern, users, insert_location

            replace = false
            replacements = []

            @@main.config['highlightstrings'].each do |term|
                exists = false
                replacement = nil
                #check for a regexp
                if term[0].chr == '/' and term[-1].chr == '/'
                    #create a regexp object
                    re = Regexp.new(term[1...-1], Regexp::IGNORECASE)

                    md = re.match(pattern)

                    replacement = md[0] if md
                else
                    if pattern.include?(term)
                        replacement = term
                    end
                end
                if replacement
                    replacements.each do |s|
                        exists = true if s.include?(replacement)
                    end
                end

                if !exists and replacement
                    replace = true
                    replacements.push(term)
                    color = @@main.config['highlightplugincolor'].to_hex
                    puts pattern
                    pattern.gsub!(replacement, '<span color="'+color+'">'+replacement+'</span>')#you can change the highlight color here...
                    puts pattern
                end
            end

            if replace
                if insert_location == BUFFER_END
                    command = @@main.config['highlightcommand']
                    if command != 'none'
                        system command
                    end
                    set_status(HIGHLIGHT)
                end
            end

            [uname, pattern, users, insert_location]
        end
    end

    def configure
        value = @@main.config['highlightplugincolor']
        value ||= Color.new(65535, 65535, 0)
        return [{'type' => Color, 'name' => 'highlightplugincolor',
            'value' => value, 'description' => 'Highlight Color'},
            {'type' => Array, 'name' => 'highlightstrings', 
                'value' => @@main.config['highlightstrings'], 'description' => 'Strings or Regexp to highlight',
                'tooltip' => 'Comma seperated list of strings/regexps to highlight. Regexps are surrounded with /s'},
                {'type' => String, 'name' => 'highlightcommand',
                    'value' => @@main.config['highlightcommand'], 'description' => 'Highlight command',
                    'tooltip' => 'System command to run when a highlight occured, none will do nothing'}]
    end
end

highlighter = Highlighter.new
Plugin.register(highlighter)
