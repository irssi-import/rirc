require 'utils'

class Alias
    attr_reader :commands
    def initialize(string, arguments, target)
        @target = target
        #         puts 'alias: '+string, 'arguments: '+arguments, '=>'
        @string = string
        @arguments = arguments.to_s.split(' ')
        @commands = []
        parse
    end

    def parse
        re = /\s*;\s*\//
        string = @string.dup

        while md = re.match(string)
            command, string = string.split(md[0], 2)
            string = '/'+string
            @commands << replace_args(command)
        end

        @commands << replace_args(string)
    end

    def replace_args(string)
        unused = @arguments.dup#keep track of any unused arguments
        re = /\$(([\-0-9.]+([.]{2,3}[\-0-9]+|))|[@^!]|(?:network|presence|username|buffername))/
        md = re.match string
        return unused.unshift(string).join(' ') unless md

        while md
            if md[1] =~ /([\-0-9]+)([.]{2,3})([\-0-9]+)/
                if $1.to_i > $3.to_i
                    string.sub!(md[0], eval("@arguments[#{$3}#{$2}#{$1}]").reverse.join(' '))
                else
                    string.sub!(md[0], eval("@arguments[#{md[1]}]").join(' '))
                end
            elsif md[1].numeric?
                if @arguments[md[1].to_i]
                    string.sub!(md[0], @arguments[md[1].to_i])
                    unused.delete(@arguments[md[1].to_i])
                else #can't replace an argument that we don't have in the array
                    string.sub!(md[0], '$\\\\'+md[1])#escape it so we don't infinitely loop
                end
            elsif md[1] == '@'
                string.sub!(md[0], @arguments.join(' '))
            elsif md[1] == '^'
                string.sub!(md[0], unused.join(' '))
            elsif md[1] == '!'
                string.sub!(md[0], '')
            else
                case md[1]
                when 'network'
                    replace = @target.network.name
                when 'presence'
                    replace = @target.presence
                when 'username'
                    replace = @target.username
                when 'buffername'
                    replace = @target.name
                else
                    replace = ''
                end
                string.sub!(md[0], replace)
            end
            md = re.match string
        end
        string.gsub('$\\', '$') #unescape any escaped $<num>s
    end
end

# class NetworkBuffer
#     attr_reader :name, :presence, :username, :network
#     def initialize(name, presence, foo)
#         @name = name
#         @username = presence
#         @presence = presence
#         @network = self
#     end
# end

# x = Alias.new('/msg nickserv recover; /msg nickserv release; /nick $0; /msg nickserv identify $1', 'user pass', NetworkBuffer.new('Freenode', 'Vag', nil))

# puts x.commands

# x = Alias.new('$network $presence $username $buffername', nil, NetworkBuffer.new('Freenode', 'Vag', nil))

# puts x.commands


