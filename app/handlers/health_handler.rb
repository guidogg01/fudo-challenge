# frozen_string_literal: true

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

  # A failing dependency is reported, never raised; the cause goes only to the log.
  def check(dependency)
    yield
    "ok"
  rescue StandardError => e
    LOGGER.warn(event: "health_check_failed", dependency: dependency, error_class: e.class.name)
    "error"
  end
end
