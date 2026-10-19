# frozen_string_literal: true

# Single entry point that loads the application. Used by config.ru (web),
# by Sidekiq (worker) and by the test suite, so all three see the same code.

require "bundler/setup"
require "json"

require_relative "../app/handlers/health_handler"
