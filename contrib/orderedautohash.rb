# = OrderedAutoHash
#
# == Version
#  1.2005.08.16 (increase of the first number means Big Change)
#
# == Description
#  OrderedHash with auto initialization (cool!)
#
# == Usage
#  Require orderedautohash.rb and use OrderedAutoHash instead of Hash (examples are at the end).
#  You can try to run orderedautohash.rb.
#
#  Example:
#
#   oah = OrderedAutoHash::new
#
#   oah['section one']['param one'] = 4
#   oah['section one']['param two'] = 2
#
#   oah['section two']['param one'] = 4
#   oah['section two']['param two'] = 2
#
#   puts oah.to_yaml
#
#   # which outputs
#   # ---
#   # section one:
#   #   param one: 4
#   #   param two: 2
#   # section two:
#   #   param one: 4
#   #   param two: 2
#
# == Source
# http://simplypowerful.1984.cz/orderedhash/1.2005.08.16
#
# == Author
#  Ara.T.Howard (/Ara/dot/T/dot/Howard/at/noaa/dot/gov)
#
# == Licence
#  You can redistribute it and/or modify it under the same terms of Ruby's license;
#  either the dual license version in 2003, or any later version.
#

require 'orderedhash.rb'

class OrderedAutoHash < OrderedHash

    def initialize(*args)
	super(*args){|a,k| a[k] = self.class::new(*args)}
    end
    
    def class
	Hash
    end
    
end

#=end

if __FILE__ == $0

    require 'yaml'
    
    oah = OrderedAutoHash::new
    
    oah['section one']['param one'] = 4
    oah['section one']['param two'] = 2
	  
    oah['section two']['param one'] = 4
    oah['section two']['param two'] = 2
		
    puts oah.to_yaml
		   
    # which outputs
    # ---
    # section one:
    #   param one: 4
    #   param two: 2
    # section two:
    #   param one: 4
    #   param two: 2

end


# END
