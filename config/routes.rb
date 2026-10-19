# frozen_string_literal: true

ROUTES = [
  Route.new("POST", "/auth/login", LoginHandler.new, public: true, json_body: true),
  Route.new("POST", "/auth/logout", LogoutHandler.new, public: false),
  Route.new("POST", "/products", CreateProductHandler.new, public: false, json_body: true),
  Route.new("GET", "/AUTHORS", AuthorsHandler.new, public: true),
  Route.new("GET", "/health", HealthHandler.new, public: true)
].freeze
