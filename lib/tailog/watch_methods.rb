require 'active_support/core_ext/string'
require 'active_support/configurable'
require 'securerandom'
require 'logger'

module Tailog
  module WatchMethods
    include ActiveSupport::Configurable

    class << self
      attr_accessor :request_id

      def logger
        return @logger if @logger
        @logger = Logger.new(File.join Tailog.log_path, "watch_methods.log")
        @logger.formatter = proc do |severity, datetime, progname, message|
          content = ""
          content << "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]"
          content << "[#{Tailog::WatchMethods.request_id}]" if Tailog::WatchMethods.request_id
          content << " #{severity.rjust(5)}"
          content << " (#{progname})" if progname
          content << ": #{message.gsub(/\\n\\s*/, " ")}"
          content << "\n"
          content
        end
        @logger
      end
    end

    class RequestId
      def initialize(app)
        @app = app
      end

      def call(env)
        Tailog::WatchMethods.request_id = external_request_id(env) || internal_request_id
        @app.call(env).tap do |_status, headers, _body|
          headers["X-Request-Id"] = Tailog::WatchMethods.request_id
        end
      end

      private

      def external_request_id(env)
        if request_id = env["HTTP_X_REQUEST_ID"].presence
          request_id.gsub(/[^\w\-]/, "").first(255)
        end
      end

      def internal_request_id
        SecureRandom.uuid
      end
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
  end
end
