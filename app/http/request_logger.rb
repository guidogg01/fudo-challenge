# frozen_string_literal: true

# Nunca loguea headers ni bodies: pueden llevar contraseñas y tokens.
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
    @logger.add(
      severity_for(status),
      event: "request",
      method: env["REQUEST_METHOD"],
      path: env["PATH_INFO"],
      status: status,
      duration_ms: duration_ms,
      request_id: env[RequestId::ENV_KEY],
      user_id: env[ApiRequest::CURRENT_USER_KEY]&.id
    )
  end

  # Así se pueden filtrar los problemas por nivel: 5xx son fallas nuestras, 4xx del cliente.
  def severity_for(status)
    if status >= 500 then Logger::ERROR
    elsif status >= 400 then Logger::WARN
    else Logger::INFO
    end
  end
end
