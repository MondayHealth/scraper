module Jobs
  module Concerns
    module LoggedJob
      def before_perform_log_job(*args)
        STDOUT.write "Performing #{self} with #{args.inspect}"
      end

      def after_perform_log_job(*args)
        STDOUT.write "Finished performing #{self} with #{args.inspect}"
      end

      def on_failure_log_job(*args)
        STDOUT.write "Failed #{self} with #{args.inspect}"
      end
    end
  end
end