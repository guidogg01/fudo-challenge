# frozen_string_literal: true

class HealthHandler
  def call(request)
    checks = {
      database: check(:database, request) { DB.get(1) },
      redis: check(:redis, request) { Sidekiq.redis { |connection| connection.call("PING") } }
    }
    healthy = checks.values.all?("ok")

    body = { status: healthy ? "ok" : "error", checks: checks }
    JsonResponse.build(healthy ? 200 : 503, body)
  end

  private

  # Una dependencia caída se informa, nunca se propaga; la causa va solo al log.
  def check(dependency, request)
    yield
    "ok"
  rescue StandardError => e
    LOGGER.warn(event: "health_check_failed", dependency: dependency, error_class: e.class.name,
                request_id: request.request_id)
    "error"
  end
end
