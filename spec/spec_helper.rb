# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
# The lowest cost bcrypt accepts: hashing stays fast in tests.
ENV["BCRYPT_COST"] = "4"

# The models need the tables, so the test database is migrated before the
# application is loaded.
require_relative "../config/database"
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path("../db/migrations", __dir__))

require_relative "../config/boot"
require "rack/builder"
require "rack/test"

# Request specs exercise the same Rack app that Puma serves, built from config.ru.
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

  # Every example runs inside a transaction that is rolled back at the end,
  # so examples never see rows written by other examples. auto_savepoint
  # turns the transactions opened inside an example into savepoints, so a
  # failed insert does not break the rest of the example.
  config.around do |example|
    DB.transaction(rollback: :always, auto_savepoint: true) { example.run }
  end

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
