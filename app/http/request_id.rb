# frozen_string_literal: true

require "securerandom"

class RequestId
  ENV_KEY = "app.request_id"
  # Limits what a client can put in our logs to a short, plain identifier.
  VALID_ID = /\A[\w.:-]{1,128}\z/

  def initialize(app)
    @app = app
  end

  def call(env)
    client_id = env["HTTP_X_REQUEST_ID"]
    request_id = client_id&.match?(VALID_ID) ? client_id : SecureRandom.uuid
    env[ENV_KEY] = request_id

    status, headers, body = @app.call(env)
    headers["x-request-id"] = request_id
    [status, headers, body]
  end
end
