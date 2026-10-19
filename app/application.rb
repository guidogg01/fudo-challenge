# frozen_string_literal: true

require "rack/builder"
require "rack/deflater"

# The order matters: Deflater sits outside ErrorHandler so error responses
# are compressed too (decision 28), and the logger sits outside both so it
# sees the final status of every request.
module Application
  def self.build(routes, logger: LOGGER)
    Rack::Builder.new do
      use RequestId
      use RequestLogger, logger: logger
      use Rack::Deflater
      use ErrorHandler, logger: logger
      run Router.new(routes)
    end
  end
end
