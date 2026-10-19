# frozen_string_literal: true

# The only place that turns exceptions into HTTP responses, always with the
# same body: { "error": { "code", "message", "details" } }
# (see DECISIONS.md, decision 20).
class ErrorHandler
  def initialize(app, logger:)
    @app = app
    @logger = logger
  end

  def call(env)
    @app.call(env)
  rescue ApiError => e
    error_response(e.status, e.code, e.message, e.details, e.headers)
  rescue StandardError => e
    # The client gets a generic 500; the details go only to the log.
    log_unexpected(env, e)
    error_response(500, "internal_error", "Ocurrió un error inesperado.", [], {})
  end

  private

  def error_response(status, code, message, details, headers)
    JsonResponse.build(status, { error: { code: code, message: message, details: details } }, headers)
  end

  def log_unexpected(env, error)
    @logger.error(
      event: "unhandled_error",
      request_id: env[RequestId::ENV_KEY],
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(10)
    )
  end
end
