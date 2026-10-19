# frozen_string_literal: true

# Loaded by Puma, Sidekiq, Rake and the tests, so all of them run the same code.

require "bundler/setup"
require "bcrypt"
require "json"
require "rack"
require "rack/files"
require "sidekiq"

require_relative "database"
require_relative "logger"

Sequel::Model.plugin :timestamps, update_on_create: true

# Models read their table's columns when they are defined, so the schema
# must already be migrated at this point.
require_relative "../app/models/user"
require_relative "../app/models/auth_token"
require_relative "../app/models/product"
require_relative "../app/models/product_request"
require_relative "../app/errors"
require_relative "../app/http/json_response"
require_relative "../app/http/api_request"
require_relative "../app/http/json_body"
require_relative "../app/http/route"
require_relative "../app/http/router"
require_relative "../app/http/request_id"
require_relative "../app/http/request_logger"
require_relative "../app/http/error_handler"
require_relative "../app/services/login"
require_relative "../app/services/token_authentication"
require_relative "../app/handlers/authors_handler"
require_relative "../app/handlers/health_handler"
require_relative "../app/handlers/login_handler"
require_relative "../app/handlers/logout_handler"
require_relative "../app/application"
require_relative "routes"
