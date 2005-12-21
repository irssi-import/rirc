require 'main'

$0 = "rirc"

#start the ball rolling...
if $args['debug']
    puts 'no rescue'
    $config = Configuration.new
	$main = Main.new
	$main.start
else
    begin
        $config = Configuration.new
        $main = Main.new
        $main.start
    rescue Interrupt => detail
        puts 'got keyboard interrupt'
        $main.window.quit
        $main.quit
    end
end