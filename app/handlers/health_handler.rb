# frozen_string_literal: true

# Reports whether the app is up. Checks for PostgreSQL and Redis are added
# once those connections exist (see DECISIONS.md, decision 27).
class HealthHandler
  def call(_env)
    [200, { "content-type" => "application/json" }, [JSON.generate(status: "ok")]]
  end
end
