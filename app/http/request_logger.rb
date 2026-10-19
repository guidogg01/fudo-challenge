# frozen_string_literal: true

# Writes one structured log line per request (see DECISIONS.md, decision 29).
# Only the method and the path are logged: never headers or bodies, which can
# carry passwords and tokens.
class RequestLogger
  def initialize(app, logger:)
    @app = app
    @logger = logger
  end

  def call(env)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)

    log(env, status, duration_ms)
    [status, headers, body]
  end

  private

  def log(env, status, duration_ms)
    @logger.info(
      event: "request",
      method: env["REQUEST_METHOD"],
      path: env["PATH_INFO"],
      status: status,
      duration_ms: duration_ms,
      request_id: env[RequestId::ENV_KEY],
      user_id: env[ApiRequest::CURRENT_USER_KEY]&.id
    )
  end
end
