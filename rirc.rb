#!/usr/bin/env ruby

require 'main'

$0 = "rirc"

#start the ball rolling...
if $args['debug']
    puts 'no rescue'
    main = Main.new
    main.start
else
    begin
        main = Main.new
        main.start
    rescue Interrupt => detail
        puts 'got keyboard interrupt'
        main.windows.each{|win| win.quit(false)}
        main.quit
    end
end
