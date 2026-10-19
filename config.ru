# frozen_string_literal: true

require_relative "config/boot"

# Temporary wiring: the hand-written router replaces this in the HTTP
# infrastructure step.
map "/health" do
  run HealthHandler.new
end

run ->(_env) { [404, { "content-type" => "application/json" }, [JSON.generate(error: "not_found")]] }
