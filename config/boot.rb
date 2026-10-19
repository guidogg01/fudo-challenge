# frozen_string_literal: true

# Single entry point that loads the application. Used by config.ru (web),
# by Sidekiq (worker), by the db:seed task and by the test suite, so all of
# them see the same code.

require "bundler/setup"
require "bcrypt"
require "json"
require "sidekiq"

require_relative "database"

# Fills created_at on insert and updated_at on every save. Tables without
# updated_at (auth_tokens) only get created_at.
Sequel::Model.plugin :timestamps, update_on_create: true

# Models read their table's columns when they are defined, so the schema
# must already be migrated at this point.
require_relative "../app/models/user"
require_relative "../app/models/auth_token"
require_relative "../app/models/product"
require_relative "../app/models/product_request"
require_relative "../app/handlers/health_handler"
