class BufferView
    attr_reader :lines, :view
    def initialize
        @view = Scw::View.new
        @liststore = Gtk::ListStore.new(Scw::Timestamp, Scw::Presence, String, Scw::RowColor)
        @view.model = @liststore
        @view.align_presences = $config['scw_align_presences']
        @view.scroll_on_append = true
        @view.modify_font(Pango::FontDescription.new($config['main_font']))
        @view.modify_text(Gtk::STATE_NORMAL, $config['foregroundcolor'])
        @view.modify_text(Gtk::STATE_SELECTED, $config['selectedforegroundcolor'])
        @view.modify_base(Gtk::STATE_SELECTED, $config['selectedbackgroundcolor'])
        @view.modify_text(Gtk::STATE_ACTIVE, $config['selectedforegroundcolor'])
        @view.modify_base(Gtk::STATE_ACTIVE, $config['selectedbackgroundcolor'])
        @view.modify_text(Gtk::STATE_PRELIGHT, $config['scw_prelight'])
        @lines = []
        
        @view.signal_connect("activated") do |view,id,data|
          puts "Activated #{id} with #{data}"
          if id == 'url'
                link = to_uri(data)
				fork{exec($config['linkclickaction'].sub('%s', link))}
            end
        end
    end
    
    def append(line, id)
        #puts 'appending'+line[2]
        iter = @liststore.append
        line.each_with_index do |item, i|
            iter[i] = item
        end
        @lines.push([id, Gtk::TreeRowReference.new(@liststore, iter.path)])
        trim
        #puts 'done'
        marklastread unless @lastread
    end
    
    def prepend(line, id)
        iter = @liststore.prepend
        line.each_with_index do |item, i|
            iter[i] = item
        end
        @lines.unshift([id, Gtk::TreeRowReference.new(@liststore, iter.path)])
        trim
    end
    
    def remove_id(id)
        item = @liststore.detect{|x| x[0] == id}
        @liststore.remove(@liststore.get_iter(item[1].path))
    end
    
    def remove_path(path)
        item = @liststore.detect{|x| x[1].path == path}
        @liststore.remove(@liststore.get_iter(item[1].path))
    end
    
    def has_id?(id)
        return @lines.detect{|x| x[0] == id}
    end
    
    def trim
        #@lines = @lines.select{|x| x[1].valid?}
        if @lines.length > 100
            #puts 'trimming'
            (@lines.length-100).times do |x|
                id, iter = @lines.shift
                #puts iter.class
                @liststore.remove(@liststore.get_iter(iter.path))
            end
        end
        #puts @lines.length
    end
    
    def marklastread
        id, iter = @lines[-1]
        return unless iter
        
        iter3 = @liststore.get_iter(iter.path)
        
        if @lastread and @lastread.valid?
            iter2 = @liststore.get_iter(@lastread.path)
            iter2[3] = ''
        end
        
        iter3[3] = $config['scw_lastread'].to_hex
        @lastread = iter
    end
end