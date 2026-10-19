# frozen_string_literal: true

# Reports whether the app can do its work: 200 when PostgreSQL and Redis
# answer, 503 with the one that failed otherwise (see DECISIONS.md, decision 27).
class HealthHandler
  def call(_request)
    checks = {
      database: check(:database) { DB.get(1) },
      redis: check(:redis) { Sidekiq.redis { |connection| connection.call("PING") } }
    }
    healthy = checks.values.all?("ok")

    body = { status: healthy ? "ok" : "error", checks: checks }
    JsonResponse.build(healthy ? 200 : 503, body)
  end

  private

  # Any error means "not available": the health check must answer, not raise.
  # The cause goes to the log, never to the response.
  def check(dependency)
    yield
    "ok"
  rescue StandardError => e
    LOGGER.warn(event: "health_check_failed", dependency: dependency, error_class: e.class.name)
    "error"
  end
end
