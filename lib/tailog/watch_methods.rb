require 'active_support/core_ext/string'
require 'securerandom'
require 'logger'
require 'erb'

module Tailog
  module WatchMethods
    class << self
      attr_accessor :inject_options

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

    self.inject_options = {
      self: true,
      arguments: true,
      caller_backtrace: false,
      result: true,
      error_backtrace: true
    }

    def inject targets, options = {}
      options = Tailog::WatchMethods.inject_options.merge(options)
      targets.each do |target|
        begin
          if target.include? "#"
            inject_instance_method target, options
          elsif target.include? "."
            inject_class_method target, options
          else
            inject_constant target, options
          end
        rescue => error
          WatchMethods.logger.error "Inject #{target} FAILED: #{error.class}: #{error.message}."
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

    def inject_constant target, options
      constant = target.constantize
      constant.instance_methods(false).each do |method|
        inject_instance_method "#{target}##{method}", options unless raw_method? method
      end
      constant.methods(false).each do |method|
        inject_class_method "#{target}.#{method}", options unless raw_method? method
      end
    end

    def cleanup_constant target
      constant = target.constantize
      constant.instance_methods(false).each do |method|
        cleanup_instance_method "#{target}##{method}" unless raw_method? method
      end
      constant.methods(false).each do |method|
        cleanup_class_method "#{target}.#{method}" unless raw_method? method
      end
    end

    def inject_class_method target, options
      klass, _, method = target.rpartition(".")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        class << self
          #{build_watch_method target, method, options}
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

    def inject_instance_method target, options
      klass, _, method = target.rpartition("#")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        #{build_watch_method target, method, options}
      EOS
    end

    def cleanup_instance_method target
      klass, _, method = target.rpartition("#")
      klass.constantize.class_eval <<-EOS, __FILE__, __LINE__
        #{build_cleanup_method target, method}
      EOS
    end

    def build_watch_method target, method, options
      raw_method = "#{RAW_METHOD_PREFIX}#{method}"
      ERB.new(WATCH_METHOD_ERB).result(binding)
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

WATCH_METHOD_ERB = <<-EOS
  unless instance_methods.include?(:<%= raw_method %>)
    alias_method :<%= raw_method %>, :<%= method %>
    def <%= method %> *args
      start = Time.now
      call_id = SecureRandom.uuid

      Tailog::WatchMethods.logger.info "[\#{call_id}] <%= target %> CALLED<% if options[:self] %>, self: \#{self.inspect}<% end %><% if options[:arguments] %>, arguments: \#{args.inspect}<% end %><% if options[:caller_backtrace] %>, backtrace: \#{caller.join(", ")}<% end %>."

      result = send :<%= raw_method %>, *args

      Tailog::WatchMethods.logger.info "[\#{call_id}] <%= target %> FINISHED in \#{(Time.now - start) * 1000} ms<% if options[:result] %>, result: \#{result.inspect}<% end %>."

      result
    rescue => error
      Tailog::WatchMethods.logger.error "[\#{call_id}] <%= target %> FAILED: \#{error.class}: \#{error.message}<% if options[:error_backtrace] %>, backtrace: \#{error.backtrace.join(", ")}<% end %>."

      raise error
    end
  else
    Tailog::WatchMethods.logger.error "Inject <%= target %> FAILED: already injected."
  end
EOS
