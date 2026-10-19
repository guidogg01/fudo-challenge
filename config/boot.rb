# frozen_string_literal: true

# Lo cargan Puma, Sidekiq, Rake y los tests, así todos corren el mismo código.

require "bundler/setup"
require "bcrypt"
require "json"
require "rack"
require "rack/files"
require "sidekiq"

require_relative "database"
require_relative "logger"

Sequel::Model.plugin :timestamps, update_on_create: true

# Los modelos leen las columnas de su tabla al definirse, así que el esquema
# ya tiene que estar migrado en este punto.
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
require_relative "../app/services/product_input"
require_relative "../app/jobs/create_product_job"
require_relative "../app/services/request_product_creation"
require_relative "../app/services/requeue_stale_requests"
require_relative "../app/serializers/product_request_serializer"
require_relative "../app/handlers/authors_handler"
require_relative "../app/handlers/create_product_handler"
require_relative "../app/handlers/product_request_handler"
require_relative "../app/handlers/health_handler"
require_relative "../app/handlers/login_handler"
require_relative "../app/handlers/logout_handler"
require_relative "../app/application"
require_relative "routes"
require_relative "sidekiq"
