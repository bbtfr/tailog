module Tailog
  class RequestId
    def initialize app
      @app = app
    end

    def call env
      Tailog.request_id = external_request_id(env) || internal_request_id
      @app.call(env).tap do |_status, headers, _body|
        headers["X-Request-Id"] = Tailog.request_id
      end
    end

    private

    def external_request_id env
      env["HTTP_X_REQUEST_ID"].presence
    end

    def internal_request_id
      SecureRandom.uuid
    end
  end
end
