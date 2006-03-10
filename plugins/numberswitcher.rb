#A simple plugin to test the command_missing callback
#allows commands like /12 to be issued which then will switch to that tab

class NumberSwitcher < Plugin
    def load
        add_callback(self, Main, :command_missing) do |command, arguments, target|
#             puts command.class, command
            if command.numeric?
#                 puts 'is numeric', target
                window = find_windows_with_buffer(target)
#                 puts window
                unless window.empty?
                    buffer = window[0].buffers.model.structure[command.to_i]
                    if buffer
                        throw_message "I'd switch to #{buffer.name}"
                        window[0].buffers.set_active(buffer)
                    else
                        throw_error "Can't find a buffer numbered #{command}"
                    end
                end
                true
            end
        end
    end

end

Plugin.register(NumberSwitcher.new)
