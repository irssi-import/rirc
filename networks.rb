require 'gtk2'
Gtk::init
require 'gtk/bufferlistview'

#hopefully, the program will only need access to the controller, so wrap all the useful stuff here?
class BufferListController
    #include PluginAPI
    #include BufferParser
    attr_reader :view, :config, :window
    def initialize(window, console=false)
        @window = window
        @config = window.config
        @model = BufferListModel.new(self, console)
        set_sort(BufferListModel::HIERARCHICAL)
        set_comparator(BufferListModel::INSENSITIVE)
        #initialize the view with the references it needs
        @view = HBoxBufferListView.new(self, @model)
        @model.view = view #give the model a reference to the view
        @window.switch_buffer(@model.console) if @model.console
    end

    def console
        @model.console
    end

    #most of these wrap model functions...
    #~ def add_network(name, presence)
    #~ @model.add_network(name, presence)
    #~ end
    
    def next_buffer
        index = @model.structure.index(active)+1
        index %= @model.structure.length
        set_active(@model.structure[index])
    end

    def prev_buffer
        index = @model.structure.index(active)-1
        set_active(@model.structure[index])
    end

    def connect(buffer)
        if buffer.respond_to? 'connect'
            #buffer.connect
            @model.sort
            set_active(buffer) if buffer.connected?
        end
    end

    def join(buffer)
        if buffer.respond_to? 'join'
            #buffer.connect
            @model.sort
            set_active(buffer) if buffer.joined?
        end
    end

    def add_buffer(buffer)
        return unless buffer
#         puts 'adding to window'
        buffer.controller = self
        case buffer
        when NetworkBuffer
#             puts 'network'
            @model.add_network(buffer)
        when ChannelBuffer
            @model.add_channel(buffer)
        when ChatBuffer
            @model.add_chat(buffer)
            set_active(buffer)
        end
    end

    #~ def add_chat(name, network)
    #~ @model.add_chat(name, network)
    #~ end

    #~ def add_channel(name, network)
    #~ @model.add_channel(name, network)
    #~ end

    def find_network(name, presence)
        @model.find_network(name, presence)
    end

    #here we provide a unified function for looking up channels/chats
    def find_chat(*args)
        if args.length == 2
            @model.find_chat_in_network(*args)
        elsif args.length == 3
            @model.find_chat(*args)
        else
            raise ArgumentError, 'function takes 2 or 3 arguments'
        end
    end

    def find_channel(*args)
        if args.length == 2
            @model.find_channel_in_network(*args)
        elsif args.length == 3
            @model.find_channel(*args)
        else
            raise ArgumentError, 'function takes 2 or 3 arguments'
        end
    end

    def close_buffer(buffer)
        return unless buffer
        case buffer
        when NetworkBuffer
            #puts 'network'
            #@model.add_network(buffer)
        when ChannelBuffer
            #@model.add_channel(buffer)
        when ChatBuffer
            @model.remove_chat(buffer)
            @window.main.remove_buffer(buffer)
        end
        @model.sort
        @window.switch_buffer(@model.active)
    end

    def active
        @model.active
    end

    def channels
        @model.channels
    end

    def networks
        @model.networks
    end

    def chats
        @model.chats
    end

    def remove_network(obj)
        @model.remove_network(obj)
    end

    def remove_channel(obj)
        @model.remove_channel(obj)
    end

    def remove_chat(obj)
        @model.remove_chat(obj)
    end

    #do some prefunctory checking here...
    def set_sort(block)
        return if @model.sort and @model.sort == block
        @model.set_sort(block)
    end

    def set_comparator(block)
        return if @model.comp and @model.comp == block
        @model.set_comparator(block)
    end


    def set_status(object, status)
        @model.set_status(object, status) if @model
    end

    def set_active(object)
        #if the model includes the object and the model isn't already set this as active
        if @model.structure.include? object and @model.active != object
            @model.set_active(object)
        end
        #switch the window to display this tab
        @window.switch_buffer(object) unless @window.currentbuffer == object
    end
end

#model, so all the data munging here, the controller should protect us from too much invalid nonsense
class BufferListModel
    attr_reader :structure, :view, :sort, :comp, :active, :console, :networks, :channels, :chats

    #ooh look, the layout/sort algorithms are pluggable. me++
    HIERARCHICAL = Proc.new do |console, networks, channels, chats, comp|
        res= []
        res << console if console
        networks.sort(&comp).each do |n|
            res << n
            channels.select{|c| c.network == n}.sort(&comp).each{|c| res << c}
            chats.select{|c| c.network == n}.sort(&comp).each{|c| res << c}
        end
        res
    end

    FLAT = Proc.new do |console, networks, channels, chats, comp|
        res= []
        res << console if console
        channels.sort(&comp).each{|x| res << x}
        chats.sort(&comp).each{|x| res << x}
        res
    end

    SENSITIVE = Proc.new{|x, y| x.name<=>y.name}
    INSENSITIVE = Proc.new{|x, y| x.name.downcase<=>y.name.downcase}

    def initialize(controller, console=false)
        @controller = controller
        @networks = []
        @channels = []
        @chats = []
        @structure = []
        if console
            @console = console#ConsoleBuffer.new(@controller)
            console.add_controller(@controller)
            set_active(@console)
        end
    end

    def view=(view)
        @view = view
        sort
        view.fill
    end

    def set_status(object, status)
#         puts object, status, object.status
        object.status = status if status > object.status or status == 0
        @view.update_status(object)
    end

    #set the block to use to sort the networks/channels/chats
    def set_sort(block)
        @sort = block
        sort
    end

    #set the block used to compare networks/channels/chats
    def set_comparator(block)
        @comp = block
        sort
    end

    #updates the view, then stores the new active
    def set_active(obj)
        @active.set_status(0) if @active
#         obj.set_status(0)
#         @view.update_status(obj) if @view
        @view.set_active(obj) if @view
        @active = obj
    end

    def add_network(network)
        @networks << network
        sort
        #set_active(network)
    end

    def add_channel(channel)
        @channels << channel
        sort
        #set_active(channel)
    end

    def add_chat(chat)
        @chats << chat
        sort
        #set_active(chat)
    end

    #~ #takes a name string
    #~ def add_network(name, presence)
    #~ unless network = @networks.detect{|n| n.name == name and n.presence == presence}
    #~ network = NetworkBuffer.new(@controller, name, presence)
    #~ @networks << network
    #~ end
    #~ sort
    #~ network
    #~ end

    #~ def add_channel(name, network)
    #~ unless channel = @channels.detect{|c| c.name == name and c.network = network}
    #~ channel = ChannelBuffer.new(@controller, name, network)
    #~ @channels << channel
    #~ end
    #~ sort
    #~ channel
    #~ end

    #~ def add_chat(name, network)
    #~ unless chat = @chats.detect{|c| c.name == name and c.network = network}
    #~ chat = ChatBuffer.new(@controller, name, network)
    #~ @chats << chat
    #~ end
    #~ sort
    #~ set_active(chat)
    #~ chat
    #~ end

    #takes a Network object
    def remove_network(network)
#         puts network.class
        @networks.delete(network)
        @channels.delete_if{|x| x.network == network}
        @chats.delete_if{|x| x.network == network}
        sort
    end

    #takes a Channel object
    def remove_channel(channel)
        @channels.delete(channel)
        sort
    end

    #takes a Chat object
    def remove_chat(chat)
        @chats.delete(chat)
        sort
    end

    def find_network(name, presence)
        @networks.detect{|n| n.name == name and n.presence == presence}
    end

    def find_channel(networkname, presence, channelname)
        res = nil
        if network = find_network(networkname, presence)
            res = find_channel_in_network(network, channelname)
        end
        return res
    end

    def find_chat(networkname, presence, chatname)
        res = nil
        if network = find_network(networkname, presence)
            res = find_chat_in_network(network, chatname)
        end
        return res
    end

    #needs a network object
    def find_channel_in_network(network, name)
        @channels.detect{|x| x.network == network and x.name == name}
    end

    def find_chat_in_network(network, name)
        @chats.detect{|x| x.network == network and x.name == name}
    end

    def sort
        return unless @sort and @comp
        oldstructure = @structure
        @structure = @sort.call(@console, @networks.select{|x| x.buffer}, @channels.select{|x| x.buffer}, @chats.select{|x| x.buffer}, @comp)
        return @structure unless @view

        #check if its an add or a delete
        #TODO - renames, mainly for chats
        if oldstructure.length < @structure.length
            (@structure - oldstructure).each do |x|
                index = @structure.index(x)
                if index == 0
                    obj = nil
                else
                    obj = @structure[index-1]
                end
                #insert passes the object to be inserted and the object that comes before it
                #this makes it easier to determine where to insert (I think)
                @view.insert(x, obj)
            end
        elsif oldstructure.length > @structure.length
            (oldstructure - @structure).each do |x|
                @view.remove(x)
            end
        end

        #switch the active tab if the active one got removed
        unless @structure.include? @active
            if oldstructure.index(@active) == 0
                set_active(@structure[0])
            elsif oldstructure.include? @active
                set_active(oldstructure[oldstructure.index(@active)-1])
            end
        end
        @structure
    end
end

class Buffer
    include PluginAPI
    include BufferParser
    include TabCompleteModule
    attr_reader :buffer, :name, :commandbuffer, :controller, :main
    attr_accessor :status
    def initialize(*args)
        @controller = nil
        @main = args[-1]
        @config = @main.config
        @status = 0
    end

    def controller=(controller)
        @controller = controller
        @config = controller.config
        @main = @controller.window.main
    end

    def set_status(status)
        @controller.set_status(self, status)
    end

    def close
        @buffer = nil
        @controller.close_buffer(self) 
    end
end

class ConsoleBuffer < Buffer
    def initialize(main)
        @main = main
        @config = @main.config
        @controllers = []
        @buffer = BufferView.new(@config)
        @name = 'Console'
        @commandbuffer = CommandBuffer.new(@config)
        @status = 0
    end

    def add_controller(controller)
        @controllers.push(controller)
    end

    def set_status(status)
        @controllers.each{|x| x.set_status(self, status)}
    end
end

class NetworkBuffer < Buffer
    attr_reader :presence, :users
    #attr_writer :username
    def initialize(name, presence, main)
        super
        @name = name
        @presence = presence
        @username = presence
        @users = UserList.new
    end

    def username
        @username
    end

    def username=(username)
        @username = username
        @controller.window.get_username if @controller.active.respond_to? :network and @controller.active.network == self
    end

    def network
        self
    end

    def connect
        @connected = true
        @buffer ||= BufferView.new(@config)
        @commandbuffer ||= CommandBuffer.new(@config)
        @controller.connect(self)
    end

    def connected?
        @connected
    end

    def disconnect
        @connected = nil
        @commandbuffer = nil
    end

    def close
        disconnect
        super
    end

    def reconnect
        #TODO
    end

    def identifier_string
        "network=#{@name};mypresence=#{@presence}"
    end
end

class ChatBuffer < Buffer
    attr_reader :network, :name, :presence, :users
    def initialize(name, network, main)
        super
        @name = name
        @network = network
        @presence = network.presence
        @buffer = BufferView.new(@config)
        @users = UserList.new
        @commandbuffer = CommandBuffer.new(@config)

        #fill the userlist... there's only 2 people in a chat
        @users.add(network.users[username])
        @users.add(network.users[name])
    end

    def username
        @network.username
    end

    def identifier_string
        "network=#{@network.name};mypresence=#{@presence};presence=#{@name}"
    end
end

class ChannelBuffer < Buffer
    attr_reader :network, :name, :presence, :users, :topic, :userlistview
    attr_accessor :eventsync, :usersync
    def initialize(name, network, main)
        super
        @topic = ''
        @name = name
        @network = network
        @presence = network.presence
        @eventsync = @usersync = false
    end

    def topic=(topic)
        @topic = topic
        @controller.window.update_topic if @controller.active == self
    end

    def username
        @network.username
    end

    def join
        @joined = true
        @buffer ||= BufferView.new(@config)
        @users ||= ChannelUserList.new
        @userlistview ||= UserListView.new(self)
        @users.view ||= @userlistview
        @commandbuffer ||= CommandBuffer.new(@config)
        @controller.join(self)
        #@userlist = SomeUnwrittenClass.new
    end

    def joined?
        @joined
    end

    def close
        @commandbuffer = nil
        @userlistview = nil
        part
        super
    end

    def part
        @joined = false
        @users = nil
        @userlistview.clear if @userlistview
        #@users.clear
    end
    def identifier_string
        "network=#{@network.name};mypresence=#{@presence};channel=#{@name}"
    end
end

#******some testing******

#~ f = NetworkController.new(nil, true)
#~ f.set_sort(NetworkModel::HIERARCHICAL)
#~ f.set_comparator(NetworkModel::INSENSITIVE)
#~ n = f.add_network('Freenode', 'Vagabond')
#~ f.add_channel('#icecap', n)
#~ f.add_channel('#aardvark', n)
#~ f.add_chat('foo', n)
#~ f.add_channel('#zztop', n)
#~ n = f.add_network('EFNet', 'Vagabond')
#~ f.add_channel('#dragonflybsd', n)
#~ f.add_channel('#Foo', n)
#~ n = f.add_network('arpanet', 'Vagabond')

#~ puts f.find_network('EFNet', 'Vagabond')
#~ puts f.find_channel('Freenode', 'Vagabond', '#icecap')
#~ puts f.find_chat('Freenode', 'Vagabond', 'foo')

#~ #f.structure.each{|x| puts x.name}
#~ Gtk::Window.new.add(f.view.widget).show_all

#~ Thread.new do
#~ sleep 4
#~ f.remove_network(f.find_network('arpanet', 'Vagabond'))
#~ f.remove_channel(f.find_channel('Freenode', 'Vagabond', '#icecap'))
#~ end

#~ Gtk::main

#~ f.sort.each{|x| puts x.name}

#~ f.remove_channel(f.find_channel('Freenode', 'Vagabond', '#icecap'))
#~ puts

#~ f.sort.each{|x| puts x.name}
