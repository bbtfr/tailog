require 'active_support/core_ext/string'
require 'logger'

module Tailog
  module WatchMethods
    def self.logger
      @logger ||= Logger.new(File.join Tailog.log_path, "watch_methods.log")
    end

    def inject_methods targets
      targets.each do |target|
        if target.include? "#"
          inject_instance_method target
        else
          inject_class_method target
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
    rescue => error
      WatchMethods.logger.error "Inject class method `#{target}' failed: #{error.class}: #{error.message}"
    end

    def inject_instance_method target
      klass, _, method = target.rpartition("#")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        #{build_watch_method target, method}
      EOS
    rescue => error
      WatchMethods.logger.error "Inject instance method `#{target}' failed: #{error.class}: #{error.message}"
    end

    def build_watch_method target, method
      raw_method = "watch_method_raw_#{method}"
      return <<-EOS
        alias_method :#{raw_method}, :#{method}
        def #{method} *args
          Tailog::WatchMethods.logger.info "Method called: #{target} with \#{args}"
          start = Time.now
          result = send :#{raw_method}, *args
          Tailog::WatchMethods.logger.info "Method finished: #{target} with \#{result} in \#{(Time.now - start) * 1000} ms"
          result
        rescue => error
          Tailog::WatchMethods.logger.error "Method failed: #{target} raises \#{error.class}: \#{error.message}\\n\#{error.backtrace.join("\\n")}"
          raise error
        end
      EOS
    end
  end
end
