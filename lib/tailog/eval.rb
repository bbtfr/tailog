module Tailog
  class Eval
    class << self
      attr_accessor :blacklist
    end

    self.blacklist = %w(/tailog)

    def initialize app
      @app = app
    end

    def call env
      if skip_call? env
        @app.call(env)
      else
        before = env["HTTP_TAILOG_EVAL_BEFORE"].presence
        after = env["HTTP_TAILOG_EVAL_AFTER"].presence
        inject = env["HTTP_TAILOG_INJECT"].presence
        inject_options = env["HTTP_TAILOG_INJECT_OPTIONS"].present? ? JSON.parse(env["HTTP_TAILOG_INJECT_OPTIONS"]).symbolize_keys : Hash.new

        binding = Object.new.send(:binding)
        binding.eval(before) if before
        Tailog.inject(inject.split(" "), inject_options) rescue nil if inject

        response = @app.call(env)

        Tailog.cleanup(inject.split(" ")) if inject
        binding.eval(after) if after

        response
      end
    end

    private

    def skip_call? env
      Tailog::Eval.blacklist.any? do |path|
        env["PATH_INFO"].start_with? path
      end
    end
  end
end
