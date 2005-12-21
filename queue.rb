require 'thread'
require 'observer'

#~ queue = Queue.new

#~ consumers = (1..3).map do |i|
    #~ Thread.new("consumer #{i}") do |name|
        #~ begin
            #~ obj = queue.deq
            #~ puts "#{name} consumed #{obj.inspect}"
            #~ sleep(rand(0.05))
        #~ end until obj == :END_OF_WORK
    #~ end
#~ end

#~ producers = (1..2).map do |i|
    #~ Thread.new("producer #{i}") do |name|
        #~ 3.times do |j|
            #~ sleep(0.1)
            #~ queue.enq("Item #{j} from #{name}")
        #~ end
    #~ end
#~ end


#~ producers.each{|th| th.join}
#~ consumers.size.times {queue.enq(:END_OF_WORK)}
#~ consumers.each{|th| th.join}

class MessageQueue < Queue
    include Observable
    
    def enq(*args)
        super
        changed
        notify_observers
    end
end

class Watcher
    def initialize(obj, &block)
        obj.add_observer(self)
        @queue = obj
        @block = block
    end
    def update
        @block.call(@queue.deq)
    end
end

#~ inputqueue = MessageQueue.new

#~ watcher = Watcher.new(inputqueue){|obj| puts obj, Time.now}

#~ inputqueue.enq('foo')
#~ sleep 5
#~ inputqueue.enq('bar')