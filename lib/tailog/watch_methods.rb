require 'active_support/core_ext/string'
require 'logger'

module Tailog
  module WatchMethods
    def self.logger
      @logger ||= Logger.new(File.join Tailog.log_path, "watch_methods.log")
    end

    def inject_methods targets
      targets.each do |target|
        begin
          if target.include? "#"
            inject_instance_method target
          else
            inject_class_method target
          end
        rescue => error
          WatchMethods.logger.error "Inject method `#{target}' failed: #{error.class}: #{error.message}"
        end
      end
    end

    private

    def inject_class_method target
      klass, _, method = if target.include? "."
          target.rpartition(".")
        else
          target.rpartition("::")
        end
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        class << self
          #{build_watch_method target, method}
        end
      EOS
    end

    def inject_instance_method target
      klass, _, method = target.rpartition("#")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        #{build_watch_method target, method}
      EOS
    end

    def build_watch_method target, method
      raw_method = "watch_method_raw_#{method}"
      return <<-EOS
        unless instance_methods.include?(:#{raw_method})
          alias_method :#{raw_method}, :#{method}
          def #{method} *args
            Tailog::WatchMethods.logger.info "Method called: #{target}, self: \#{self.inspect}, arguments: \#{args.inspect}"
            start = Time.now
            result = send :#{raw_method}, *args
            Tailog::WatchMethods.logger.info "Method finished: #{target} in \#{(Time.now - start) * 1000} ms, result: \#{result.inspect}"
            result
          rescue => error
            Tailog::WatchMethods.logger.error "Method failed: #{target}, error: \#{error.class} - \#{error.message}\\n\#{error.backtrace.join("\\n")}"
            raise error
          end
        else
          Tailog::WatchMethods.logger.error "Inject method `#{target}' failed: already injected"
        end
      EOS
    end
  end
end
