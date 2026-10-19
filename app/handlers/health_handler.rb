# frozen_string_literal: true

# Reports whether the app can do its work: 200 when PostgreSQL and Redis
# answer, 503 with the one that failed otherwise (see DECISIONS.md, decision 27).
class HealthHandler
  def call(_request)
    checks = {
      database: check { DB.get(1) },
      redis: check { Sidekiq.redis { |connection| connection.call("PING") } }
    }
    healthy = checks.values.all?("ok")

    body = { status: healthy ? "ok" : "error", checks: checks }
    JsonResponse.build(healthy ? 200 : 503, body)
  end

  private

  # Any error means "not available": the health check must answer, not raise.
  # Logging the cause is added with the structured logger.
  def check
    yield
    "ok"
  rescue StandardError
    "error"
  end
end
