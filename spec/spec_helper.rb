# frozen_string_literal: true

ENV["RACK_ENV"] = "test"

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
