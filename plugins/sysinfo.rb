#a shitty sysinfo plugin to serve as another example

class SysInfo < Plugin
    def get_uptime
        result = `uptime`
        result =~ /up (.+?),/
        line = 'Uptime:'
        line += (' '*(30-line.length))
        line += $1
    end
    
    def get_hostname
        result = `hostname`
        line = 'System Info for:'
        line += (' '*(30-line.length))
        line += result.chomp.strip
    end
    
    def get_kernel
        result = `uname -sr`
        line = 'OS/Kernel:'
        line += (' '*(30-line.length))
        line += result.chomp.strip
    end
    
    def get_ram
        result = `cat /proc/meminfo`
        line = 'Memory:'
        line += (' '*(30-line.length))
        total, free = 0
        result.split("\n").each do |l|
            key, value = l.split(':',2).map{|x| x.strip}
            if key == 'MemTotal'
                mem, foo = value.split
                total = mem.to_i/1024
            elsif key == 'MemFree'
                mem, foo = value.split
                free = mem.to_i/1024
            end
        end
        percent = ((free/total.to_f)*100).ceil
        line += "#{free}/#{total}MB(#{percent}%)"
    end
    
    def get_cpu
        result = `cat /proc/cpuinfo`
        cpus = result.split("\n\n")
        res = []
        cpus.each do |c|
            line = 'CPU INFO:'
            line += (' '*(30-line.length))
            c.split("\n").each do |l|
                #puts l
                key, value = l.split(':', 2).map{|x| x.strip}
                #puts key, value
                if key == 'model name'
                    line << value+' '
                elsif key == 'cpu MHz'
                    line << value+'MHz '
                elsif key == 'bogomips'
                    line << value+' Bogomips '
                end
            end
            res << line
        end
        res
    end
    def load
        locale =self
        help :cmd_add_highlight, "show system information"
        add_method(self, Main, 'cmd_sysinfo') do |args, target|
            
            [locale.get_hostname, locale.get_kernel, locale.get_cpu, locale.get_ram, locale.get_uptime].flatten.each do |line|
                send_command('sysinfo', "msg;#{target.identifier_string};msg=#{escape(line)}") if target.respond_to? :network and target.network != target
                target.send_user_event({'msg'=>line}, EVENT_USERMESSAGE)
            end
        end
    end
end

sysinfo = SysInfo.new
Plugin.register(sysinfo)
