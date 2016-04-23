require 'active_support/core_ext/string'
require 'securerandom'
require 'logger'

module Tailog
  module WatchMethods
    class << self
      def logger
        return @logger if @logger
        @logger = Logger.new(File.join Tailog.log_path, "watch_methods.log")
        @logger.formatter = proc do |severity, datetime, progname, message|
          content = ""
          content << "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]"
          content << "[#{Tailog.request_id}]" if Tailog.request_id
          content << " #{severity.rjust(5)}"
          content << " (#{progname})" if progname
          content << ": #{message.gsub(/\n\s*/, " ")}"
          content << "\n"
          content
        end
        @logger
      end
    end

    def inject targets
      targets.each do |target|
        begin
          if target.include? "#"
            inject_instance_method target
          elsif target.include? "."
            inject_class_method target
          else
            inject_constant target
          end
        rescue => error
          WatchMethods.logger.error "Inject #{target} FAILED: #{error.class}: #{error.message}"
        end
      end
    end

    def cleanup targets
      targets.each do |target|
        if target.include? "#"
          cleanup_instance_method target
        elsif target.include? "."
          cleanup_class_method target
        else
          cleanup_constant target
        end
      end
    end

    private

    RAW_METHOD_PREFIX = "watch_method_raw_"

    def raw_method? method
      method.to_s.start_with? RAW_METHOD_PREFIX
    end

    def inject_constant target
      constant = target.constantize
      constant.instance_methods(false).each do |method|
        inject_instance_method "#{target}##{method}" unless raw_method? method
      end
      constant.methods(false).each do |method|
        inject_class_method "#{target}.#{method}" unless raw_method? method
      end
    end

    def cleanup_constant target
      target.constantize.instance_methods(false).each do |method|
        cleanup_instance_method "#{target}##{method}" unless raw_method? method
      end
      target.constantize.methods(false).each do |method|
        cleanup_class_method "#{target}.#{method}" unless raw_method? method
      end
    end

    def inject_class_method target
      klass, _, method = target.rpartition(".")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        class << self
          #{build_watch_method target, method}
        end
      EOS
    end

    def cleanup_class_method target
      klass, _, method = target.rpartition(".")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        class << self
          #{build_cleanup_method target, method}
        end
      EOS
    end

    def inject_instance_method target
      klass, _, method = target.rpartition("#")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        #{build_watch_method target, method}
      EOS
    end

    def cleanup_instance_method target
      klass, _, method = target.rpartition("#")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        #{build_cleanup_method target, method}
      EOS
    end

    def build_watch_method target, method
      raw_method = "#{RAW_METHOD_PREFIX}#{method}"
      return <<-EOS
        unless instance_methods.include?(:#{raw_method})
          alias_method :#{raw_method}, :#{method}
          def #{method} *args
            start = Time.now
            call_id = SecureRandom.uuid
            Tailog::WatchMethods.logger.info "[\#{call_id}] #{target} CALLED: self: \#{self.inspect}, arguments: \#{args.inspect}"
            result = send :#{raw_method}, *args
            Tailog::WatchMethods.logger.info "[\#{call_id}] #{target} FINISHED: \#{(Time.now - start) * 1000} ms, result: \#{result.inspect}"
            result
          rescue => error
            Tailog::WatchMethods.logger.error "[\#{call_id}] #{target} FAILED: \#{error.class} - \#{error.message} => \#{error.backtrace.join(", ")}"
            raise error
          end
        else
          Tailog::WatchMethods.logger.error "Inject method `#{target}' failed: already injected"
        end
      EOS
    end

    def build_cleanup_method target, method
      raw_method = "#{RAW_METHOD_PREFIX}#{method}"
      return <<-EOS
        if method_defined? :#{raw_method}
          alias_method :#{method}, :#{raw_method}
          remove_method :#{raw_method}
        end
      EOS
    end
  end
end
