module Help
    attr_reader :helpstrings
    def help(a, b)
        #puts a, b
        @helpstrings ||= {}
        @helpstrings[a] = b
    end
end

class Class
    include Help
end

class Module
    include Help
end

class Object
    def help(sym)
        sym = sym.to_sym
        if self.class.helpstrings and self.class.helpstrings[sym]
            return self.class.helpstrings[sym]
        else
            #hit up the plugins for some info
            ObjectSpace.each_object(Plugin) do |klass|
                if klass.class.helpstrings and klass.class.helpstrings[sym]
                    return klass.class.helpstrings[sym]
                end
            end
        end
    end
end