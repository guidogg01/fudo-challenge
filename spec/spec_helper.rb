# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
# El costo más bajo que acepta bcrypt: el hasheo es rápido en los tests.
ENV["BCRYPT_COST"] = "4"
# Saca los logs de request de la salida de los tests. Los specs que miran logs pasan su propio logger.
ENV["LOG_LEVEL"] = "fatal"

# Los modelos necesitan las tablas, así que la base de test se migra antes de
# cargar la app.
require_relative "../config/database"
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path("../db/migrations", __dir__))

require_relative "../config/boot"
require "rack/builder"
require "rack/test"
require_relative "support/helpers"

Sidekiq.testing!(:fake)

module RackAppHelper
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.parse_file(File.expand_path("../config.ru", __dir__))
  end

  def json_body
    JSON.parse(last_response.body)
  end
end

RSpec.configure do |config|
  config.include RackAppHelper, type: :request
  config.include UserHelpers
  config.include LogHelpers

  # Cada ejemplo corre en una transacción que siempre se deshace.
  # auto_savepoint permite que un ejemplo siga después de un insert fallido.
  config.around do |example|
    DB.transaction(rollback: :always, auto_savepoint: true) { example.run }
  end
  config.before { Sidekiq::Job.clear_all }

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
