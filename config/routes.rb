# frozen_string_literal: true

# The routing table. Each route says explicitly whether it is public
# (see DECISIONS.md, decision 9).
ROUTES = [
  Route.new("POST", "/auth/login", LoginHandler.new, public: true, json_body: true),
  Route.new("GET", "/health", HealthHandler.new, public: true)
].freeze
