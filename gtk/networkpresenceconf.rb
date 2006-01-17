#~ require 'libglade2'

#~ class Object
#~ def deep_clone
#~ Marshal.load(Marshal.dump(self))
#~ end
#~ end

class NetworkPresenceConf < SingleWindow
    def initialize(main, networks, protocols)
        @main = main
        @glade = GladeXML.new("gtk/glade/network-presences.glade") {|handler| method(handler)}
        @window = @glade['networkpresencewindow']
        @networklist = Gtk::ListStore.new(String)
        @renderer = Gtk::CellRendererText.new
        @networkcolumn = Gtk::TreeViewColumn.new("Networks", @renderer, :text=>0)
        @presencelist = Gtk::ListStore.new(String)
        @presencecolumn = Gtk::TreeViewColumn.new("Presences", @renderer, :text=>0)

        @gatewaylist = Gtk::ListStore.new(String)
        @gatewaycolumn = Gtk::TreeViewColumn.new("Gateways", @renderer, :text=>0)

        @glade['networktreeview'].model = @networklist
        @glade['presencetreeview'].model = @presencelist
        @glade['gatewaytreeview'].model = @gatewaylist

        @glade['connect'].sensitive = false

        @glade['networktreeview'].append_column(@networkcolumn)
        @glade['presencetreeview'].append_column(@presencecolumn)
        @glade['gatewaytreeview'].append_column(@gatewaycolumn)

        @glade['networktreeview'].selection.signal_connect('changed') do |widget|
            draw_presences
        end
        @glade['presencetreeview'].selection.signal_connect('changed') do |widget|
            if iter = widget.selected and iter[0]
                puts iter[0]
                @glade['connect'].sensitive = true
                @glade['editpresence'].sensitive = true
                @glade['deletepresence'].sensitive = true
            else
                @glade['connect'].sensitive = false
                @glade['editpresence'].sensitive = false
                @glade['deletepresence'].sensitive = false
            end
            false
        end

        @orignetworks  = networks
        @networks = networks.deep_clone
        @protocols = protocols

        @tempgateways = ItemList.new(Gateway)

        @presencehandler = 0
        @networkhandler = 0
        @gatewayhandler = 0

        draw_networks

        @open = true

        @glade['networkpresencewindow'].show_all

    end

    def draw_networks
        @networklist.clear
        @networks.list.each do |network|
            iter = @networklist.append
            iter[0] = network.name
        end
    end

    def draw_presences
        network = get_selected_network
        unless network
            puts 'clearing'
            @presencelist.clear
            #disable buttons the user shouldn't be clicking
            @glade['editnetwork'].sensitive = false
            @glade['addpresence'].sensitive = false
            return
        end
        #reenable any disabled buttons
        @glade['editnetwork'].sensitive = true
        @glade['addpresence'].sensitive = true
        network = network[0]
        @presencelist.clear
        return unless @networks[network]
        @networks[network].presences.list.each do |presence|
            iter = @presencelist.append
            iter[0] = presence.name
        end
    end

    def fill_protocols(selected = nil)
        @glade['network_protocol'].model.clear
        match = false
        i = 0
        @protocols.list.each do |protocol|
            @glade['network_protocol'].append_text(protocol.name)
            if selected and selected.downcase == protocol.name.downcase
                @glade['network_protocol'].active = i
                match = true
            end
            i += 1
        end

        unless match
            @glade['network_protocol'].active = 0
        end
    end

    def fill_gateways(gateways)
        @gatewaylist.clear
        return unless gateways
        gateways.list.each do |gateway|
            iter = @gatewaylist.append
            iter[0] = gateway.name
        end
    end

    def fill_charsets(selected=nil)
        @glade['network_charset'].model.clear
        selected.downcase! if selected
        charsets = ['utf-8', 'iso-8859-1', 'iso-8859-2', 'iso-8859-5', 'iso-8859-15']
        unless index = charsets.index(selected)
            charsets = [selected].concat(charsets) if selected
            index = 0
        end

        charsets.each do |c|
            @glade['network_charset'].append_text(c)
        end

        @glade['network_charset'].active  = index
    end

    def get_selected_network
        iter = @glade['networktreeview'].selection.selected
        return nil unless iter
        return iter
    end

    def get_selected_presence
        iter = @glade['presencetreeview'].selection.selected
        return nil unless iter
        return iter
    end

    def get_selected_gateway
        iter = @glade['gatewaytreeview'].selection.selected
        return nil unless iter
        return iter
    end

    def add_network 
        @tempgateways = ItemList.new(Gateway)
        @glade['network_protocol'].sensitive = true
        @currentgateways = @tempgateways
        if @glade['network_ok'].signal_handler_is_connected?(@networkhandler)
            @glade['network_ok'].signal_handler_disconnect(@networkhandler)
        end
        @networkhandler = @glade['network_ok'].signal_connect('clicked') { insert_network}
        puts @networkhandler
        @glade['network_name'].text =''
        @glade['network_name'].sensitive = true
        fill_charsets
        fill_protocols
        @gatewaylist.clear
        @glade['networkpresencewindow'].modal = false
        @glade['networkproperties'].show_all
    end

    def edit_network
        if @glade['network_ok'].signal_handler_is_connected?(@networkhandler)
            @glade['network_ok'].signal_handler_disconnect(@networkhandler)
        end
        @networkhandler = @glade['network_ok'].signal_connect('clicked') { update_network}
        network = get_selected_network
        return unless network
        network = @networks[network[0]]
        return unless network
        @currentgateways = network.gateways
        @glade['network_name'].text = network.name
        @glade['network_name'].sensitive = false
        fill_protocols(network.protocol)
        fill_gateways(network.gateways)
        fill_charsets(network.charset)
        @glade['network_protocol'].sensitive = false
        @glade['networkpresencewindow'].modal = false
        @glade['networkproperties'].show_all
    end

    def remove_network
        network = get_selected_network
        return unless network
        puts network
        nw = @networks[network[0]]
        @networks.remove(nw)
        @networklist.remove(network)
    end

    def insert_network
        charset, name, protocol = nil
        charset = @glade['network_charset'].active_iter[0] if @glade['network_charset'].active_iter[0] != ''
        name = @glade['network_name'].text if name = @glade['network_name'].text != ''
        protocol = @glade['network_protocol'].active_iter[0] if @glade['network_protocol'].active_iter[0] != ''
        nw = @networks.add(name, protocol) if name and protocol
        if nw
            nw.charset = charset
            nw.gateways = @currentgateways
        end
        draw_networks
        @glade['networkproperties'].hide
        @glade['networkpresencewindow'].modal = true
    end

    def update_network
        charset, name, protocol = nil
        charset = @glade['network_charset'].active_iter[0] if @glade['network_charset'].active_iter 
        name = @glade['network_name'].text if name = @glade['network_name'].text != ''
        protocol = @glade['network_protocol'].active_iter[0] if @glade['network_protocol'].active_iter
        nw = @networks[name]
        if nw
            nw.charset = charset
            #nw.protocol = protocol if protocol
            nw.gateways = @currentgateways
        end
        draw_networks
        @glade['networkproperties'].hide
        @glade['networkpresencewindow'].modal = true
    end

    def add_presence
        network = get_selected_network
        return unless network
        if @glade['presence_ok'].signal_handler_is_connected?(@presencehandler)
            @glade['presence_ok'].signal_handler_disconnect(@presencehandler)
        end
        @presencehandler = @glade['presence_ok'].signal_connect('clicked') { insert_presence}
        @glade['presence_autoconnect'].active = false
        @glade['presence_name'].sensitive = true
        @glade['presence_name'].text = ''
        @glade['networkpresencewindow'].modal = false
        @glade['presenceproperties'].show_all
    end

    def edit_presence
        network = get_selected_network
        return unless network
        network = network[0]
        presence= get_selected_presence
        return unless presence
        presence = @networks[network].presences[presence[0]]
        return unless presence
        if @glade['presence_ok'].signal_handler_is_connected?(@presencehandler)
            @glade['presence_ok'].signal_handler_disconnect(@presencehandler)
        end
        @presencehandler = @glade['presence_ok'].signal_connect('clicked') { update_presence}
        @glade['presence_autoconnect'].active = false
        @glade['presence_name'].text = presence.name
        @glade['presence_name'].sensitive = false
        if presence.autoconnect
            @glade['presence_autoconnect'].active = true
        end
        @glade['networkpresencewindow'].modal = false
        @glade['presenceproperties'].show_all
    end

    def remove_presence
        presence = get_selected_presence
        network = get_selected_network
        return unless presence
        p = @networks[network[0]].presences[presence[0]]
        @networks[network[0]].presences.remove(p)
        @presencelist.remove(presence)
    end

    def insert_presence
        network = get_selected_network
        return unless network
        network = @networks[network[0]]
        return unless network

        name = @glade['presence_name'].text if @glade['presence_name'].text != ''
        if name
            ps = network.presences.add(name)

            if ps
                ps.autoconnect = true if @glade['presence_autoconnect'].active?
                draw_presences
                puts network.presences.list
            end
        end
        @glade['presenceproperties'].hide
        @glade['networkpresencewindow'].modal = true
    end

    def update_presence
        network = get_selected_network
        return unless network
        network = @networks[network[0]]
        return unless network
        name, autoconnect = nil
        name = @glade['presence_name'].text if @glade['presence_name'].text != ''
        autoconnect = true if @glade['presence_autoconnect'].active?

        presence = network.presences[name]
        return unless presence

        presence.autoconnect = autoconnect

        @glade['presenceproperties'].hide
        @glade['networkpresencewindow'].modal = true
    end

    def add_gateway
        @glade['gateway_host'].text = ''
        @glade['gateway_port'].text = ''
        @glade['gateway_password'].text = ''
        if @glade['network_ok'].signal_handler_is_connected?(@gatewayhandler)
            @glade['network_ok'].signal_handler_disconnect(@gatewayhandler)
        end
        @gatewayhandler = @glade['gateway_ok'].signal_connect('clicked') { insert_gateway}
        @glade['gatewayproperties'].show_all
        @glade['networkproperties'].modal = false
    end

    def edit_gateway
        network = get_selected_network
        return unless network
        network = network[0]
        gateway = get_selected_gateway
        return unless gateway
        puts gateway[0]
        gateway = @currentgateways[gateway[0]]
        puts gateway
        return unless gateway
        @glade['gateway_host'].text = gateway.host
        @glade['gateway_port'].text = gateway.port if gateway.port
        @glade['gateway_password'].text = gateway.password if gateway.password
        if @glade['gateway_ok'].signal_handler_is_connected?(@gatewayhandler)
            @glade['gateway_ok'].signal_handler_disconnect(@gatewayhandler)
        end
        @gatewayhandler = @glade['gateway_ok'].signal_connect('clicked') { update_gateway(gateway)}
        @glade['gatewayproperties'].show_all
        @glade['networkproperties'].modal = false
    end

    def remove_gateway
        network = get_selected_network
        puts network[0]
        return unless network
        network = network[0]
        gateway = get_selected_gateway
        return unless gateway
        gw = @currentgateways[gateway[0]]
        @currentgateways.remove(gw)
        @gatewaylist.remove(gateway)
    end

    def insert_gateway
        #puts network
        host, port, password = nil
        host = @glade['gateway_host'].text if @glade['gateway_host'].text != ''
        port = @glade['gateway_port'].text if @glade['gateway_port'].text != ''
        password =  @glade['gateway_password'].text if @glade['gateway_password'].text != ''
        if port
            gw = @currentgateways.add(host, port)
        else
            gw = @currentgateways.add(host)
        end
        puts gw
        if gw
            gw.password = password
            fill_gateways(@currentgateways)
        end
        @glade['gatewayproperties'].hide
        @glade['networkproperties'].modal = true
    end

    def update_gateway(gateway)
        host, port, password = nil
        host = @glade['gateway_host'].text if @glade['gateway_host'].text != ''
        port = @glade['gateway_port'].text if @glade['gateway_port'].text != ''
        password =  @glade['gateway_password'].text if @glade['gateway_password'].text != ''

        gateway.host = host
        gateway.port = port
        gateway.password = password
        @glade['gatewayproperties'].hide
        @glade['networkproperties'].modal = true
    end

    def cancel_networkproperties
        @glade['networkproperties'].hide
        @glade['networkpresencewindow'].modal = true
    end

    def cancel_presenceproperties
        @glade['presenceproperties'].hide
        @glade['networkpresencewindow'].modal = true
    end

    def cancel_gatewayproperties
        @glade['gatewayproperties'].hide
        @glade['networkproperties'].modal = true
    end

    def hide(widget, event)
        widget.hide
        return true
    end

    def connect
        network = get_selected_network
        return unless network
        network = network[0]
        presence = get_selected_presence
        if presence
            presence = presence[0]
            return unless presence
            apply
        end
        @main.send_command('connect', 'presence connect;mypresence='+presence+';network='+network)
        #connect to network presence
    end

    def apply
        destroy
        diff_networks
    end

    def diff_networks
        #~ i = 0
        #~ @networks.sort!
        #~ @orignetworks.sort!

        #add and update
        @networks.list.each do |network|
            if @orignetworks.include?(network)
                #puts 'network exists'
                diff = network.diff(@orignetworks[network.name])
                if diff
                    puts 'update network'
                    @main.send_command('editnetwork', 'network set;network='+network.name+';'+diff)
                    #@orignetworks[network.name] = network
                end
                origpresences = @orignetworks[network.name].presences
                network.presences.list.each do |presence|
                    if origpresences.include?(presence)
                        #puts 'presence exists'
                        diff = presence.diff(origpresences[presence.name])
                        if diff
                            puts 'update presence'
                            @main.send_command('editpresence', 'presence set;network='+network.name+';mypresence='+presence.name+';'+diff)
                            #origpresences[presence.name] = presence
                        end
                    else
                        puts 'add presence '+presence.name
                        @main.send_command('addpresence', presence.create(network.name))
                        #origpresences.insert(presence)
                    end
                end
                origgateways = @orignetworks[network.name].gateways
                network.gateways.list.each do |gateway|
                    if origgateways.include?(gateway)
                        #puts 'gateway exists'
                        diff = gateway.diff(origgateways[gateway.name])
                        if diff
                            puts 'update gateway'
                            @main.command_send('editgateway', 'gateway set;network='+gateway.name+';'+diff)
                            #origgateways[gateway.name] = gateway
                        end
                    else
                        puts 'add gateway '+gateway.name
                        @main.send_command('addgateway', gateway.create(network.name))
                        #origgateways.insert(gateway)
                    end
                end
            else
                puts 'add network '+network.name
                @main.send_command('addnetwork', network.create)
                sleep 0.5
                network.presences.list.each do |presence|
                    puts 'add presence '+presence.name
                    @main.send_command('addpresence', presence.create(network.name))
                end
                network.gateways.list.each do |gateway|
                    puts 'add gateway '+gateway.name
                    @main.send_command('addgateway', gateway.create(network.name))
                end
                #@orignetworks.insert(network)
            end
        end

        #remove
        @orignetworks.list.each do |network|
            if @networks.include?(network)
                newpresences = @networks[network.name].presences
                network.presences.list.each do |presence|
                    if !newpresences.include?(presence)
                        #@orignetworks[network.name].presences.remove(presence)
                        puts 'remove presence '+presence.name
                        @main.send_command('removepresence', 'presence remove;network='+network.name+';mypresence='+presence.name)
                    end
                end
                newgateways = @networks[network.name].gateways
                network.gateways.list.each do |gateway|
                    if !newgateways.include?(gateway)
                        #@orignetworks[network.name].gateways.remove(gateway)
                        puts 'remove gateway '+gateway.name
                        @main.send_command('removegateway', 'gateway remove;network='+network.name+';host='+gateway.host)
                    end
                end
            else
                #need to iterate through and remove children I guess
                #@orignetworks.remove(network)
                puts '(unimplemented) remove network '+network.name
            end
        end
    end

    def destroy
        @open = false
        @glade['networkpresencewindow'].destroy
        @glade['networkproperties'].destroy
        @glade['presenceproperties'].destroy
        @glade['gatewayproperties'].destroy
        #Gtk.main_quit
    end

end
