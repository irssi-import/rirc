#~ require 'gtk2'
#~ require 'users.rb'
#~ Gtk.init

class UserListView
    attr_accessor :widget
    def initialize(buffer)
        @buffer = buffer
        @widget = Gtk::VPaned.new
        @box = Gtk::VBox.new
        @title = Gtk::Label.new('')
        @userview = Gtk::TreeView.new
        @userview.set_headers_visible(false)
        @userlist = Gtk::ListStore.new(String, String)
        @renderer = Gtk::CellRendererText.new
        @modecolumn = Gtk::TreeViewColumn.new("Mode", @renderer, :text=>0)
        @usercolumn = Gtk::TreeViewColumn.new("Users", @renderer, :text=>1)
        @userlist.clear
        @box.pack_start(@title, false, false)
        scrolledwindow = Gtk::ScrolledWindow.new
        #frame = Gtk::Frame.new
        scrolledwindow.shadow_type=Gtk::SHADOW_ETCHED_IN
        scrolledwindow.add(@userview)
        scrolledwindow.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
        @box.pack_start(scrolledwindow)
        @widget.add1(@box)
        @useriters = []

        @userview.model = @userlist
        @userview.append_column(@modecolumn)
        @userview.append_column(@usercolumn)
        @userview.set_search_column(1)

        @userview.signal_connect('button_press_event'){|widget, event| userlist_on_click(widget, event)}
        @userview.signal_connect('row_activated'){|widget, path, column| userlist_on_doubleclick(widget, path, column)}

    end

    def userlist_on_click(widget, event)
        if event.button == 3
            path, column, x, y = widget.get_path_at_pos(event.x, event.y)
            return unless path
            widget.set_cursor(path, nil, false)
            userlist_popup_menu(widget, event)
            true
        end
    end


    def userlist_popup_menu(widget, event)
        selection = widget.selection.selected
        if selection
            menu = create_user_popup(selection[1])
            return unless menu
            menu.show_all
            menu.popup(nil, nil, event.button, event.time)
        end
    end

    def userlist_on_doubleclick(treeview, path, column)
        iter = treeview.model.get_iter(path)
        return if iter[1] == @buffer.username
        if !chat = @buffer.main.find_buffer(@buffer.network.name, @buffer.presence, nil, iter[1])
            @buffer.main.add_buffer(@buffer.network.name, @buffer.presence, nil, iter[1])
        end
#         chat.connect unless chat.connected
#         switchchannel(chat)
    end

    def create_user_popup(user)
        user = @buffer.users[user] if @buffer.users
        if user
            menu = Gtk::Menu.new
            menu.append(Gtk::MenuItem.new(user.name))
            menu.append(Gtk::MenuItem.new('hostname: '+user.hostname)) if user.hostname
            menu.append(Gtk::MenuItem.new('Last message: '+user.lastspoke.strftime('%H:%M')))
            whois = Gtk::MenuItem.new("Whois "+ user.name)
            whois.signal_connect('activate') do |w|
                @buffer.controller.window.whois(user.name)
            end
            menu.append(whois)
        else
            menu = nil
        end
        menu
    end


    def get_iter(name)
        iter = @useriters.detect{|x| x.valid? and @userlist.get_iter(x.path)[1] == name}
        return nil unless iter
        @userlist.get_iter(iter.path)
    end

    def summary=(summary)
        @title.text = summary
    end

    def add_user(user, position)
        iter = @userlist.insert(position)
        iter[0] = user.mode_symbol
        iter[1] = user.name
        @useriters << Gtk::TreeRowReference.new(@userlist, iter.path)
    end

    #~ def move(olduser, user, position)
    #~ remove_user(olduser)
    #~ add_user(user, position)
    #~ end

    def reorder(oldposition, newposition, user)
        iter = @userlist.get_iter(oldposition.to_s)
#         puts iter
        @userlist.remove(iter) if iter
        add_user(user, newposition)
        #iter[0] = user.mode_symbol
        #iter[1] = user.name
    end

    #~ def reorder(order)
    #~ first = @userlist.iter_first
    #~ #@userlist.rows_reordered(first.path, first, order)
    #~ end

    def remove_user(user)
        iter = get_iter(user)
        @userlist.remove(iter) if iter
    end

    def clear
        @userlist.clear
        @useriters.clear
    end

    def fill(model)
        @userlist.clear
        @useriters.clear
        model.users.each{|user| add_user(user, model.users.index(user))}
    end
end

#~ users = ChannelUserList.new
#~ userview = UserListView.new('foo')
#~ users.view = userview

#~ x = User.new('Vag')
#~ y = ChannelUser.new(x)
#~ y.mode = 'op'
#~ users.add(y)

#~ x = User.new('Alfonzo')
#~ y = ChannelUser.new(x)
#~ y.mode = 'op'
#~ users.add(y)

#~ x = User.new('ZZtop')
#~ y = ChannelUser.new(x)
#~ y.mode = 'voice'
#~ users.add(y)

#~ x = User.new('AA')
#~ y = ChannelUser.new(x)
#~ #y.mode = ''
#~ users.add(y)

#~ users.remove(y)

#~ win = Gtk::Window.new
#~ win.add(userview.widget)
#~ win.show_all

#~ Gtk.main
