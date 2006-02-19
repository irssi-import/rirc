#stolen from http://eigenclass.org/hiki.rb?instance_exec

class Object
    module InstanceExecHelper; end
    include InstanceExecHelper
    def instance_exec(*args, &block) # !> method redefined; discarding old instance_exec
        mname = "__instance_exec_#{Thread.current.object_id.abs}_#{object_id.abs}"
        InstanceExecHelper.module_eval{ define_method(mname, &block) }
        begin
#             puts args.inspect
            ret = send(mname, *args)
#             puts ret.inspect
        ensure
            InstanceExecHelper.module_eval{ undef_method(mname) } rescue nil
        end
#         puts ret.inspect
        ret
    end
end
# block = Proc.new {|x, y| [x, y]}
# puts instance_exec(self, 10, &block)
