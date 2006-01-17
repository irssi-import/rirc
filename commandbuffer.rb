#~ require 'gtk2'
#~ Gtk.init
#~ $config = {}
#~ $config['commandbuffersize'] = 10

class CommandBuffer
    attr_accessor :currentcommand
    def initialize(config)
        @config = config
        @commandbuffer = []
        @currentcommand = ''
        @commandindex = 0
    end
    
    #add a command to the command buffer
    def add_command(string, increment=true)
        if string.length == 0 or string == @commandbuffer[@commandindex]
            @commandindex =@commandbuffer.length
            return
        end
        @commandbuffer << string
        if @commandbuffer.length > @config['commandbuffersize'].to_i
            @commandbuffer.unshift
        end
        @commandindex =@commandbuffer.length
    end
	
    #get the last command in the command buffer
    def last_command
        @commandindex -=1 if @commandindex > 0
        command = @commandbuffer[@commandindex]
        command ||= ''
        return command
    end
	
    #get the next command in the command buffer
    def next_command
        @commandindex +=1
        if @commandindex >= @commandbuffer.length
            @commandindex = @commandbuffer.length if @commandindex > @commandbuffer.length
            return ''
        else
            return @commandbuffer[@commandindex]
        end
    end
end
#~ @buffer = CommandBuffer.new

#~ entry = Gtk::Entry.new
#~ entry.signal_connect("key_press_event"){|widget, event| input_buttons(widget, event)}
#~ entry.signal_connect("activate"){|widget| @buffer.addcommand(widget.text); widget.text=''; false}
#~ def input_buttons(widget, event)
    #~ if event.keyval == Gdk::Keyval.from_name('Up')
        #~ #storecommand(false)
        #~ widget.text = @buffer.getlastcommand
    #~ elsif event.keyval == Gdk::Keyval.from_name('Down')
        #~ #storecommand
        #~ widget.text = @buffer.getnextcommand
    #~ end
#~ end

#~ Gtk::Window.new.add(entry).show_all
#~ Gtk.main
