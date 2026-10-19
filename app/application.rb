# frozen_string_literal: true

require "rack/builder"
require "rack/deflater"

# Assembles the middleware pipeline around the router. From the outside in:
#
#   RequestId      -> every request gets an id, returned in X-Request-Id
#   RequestLogger  -> one JSON log line per request, with its duration
#   Rack::Deflater -> gzip when the client sends Accept-Encoding: gzip
#   ErrorHandler   -> exceptions become JSON error responses
#   Router         -> finds the route and calls its handler
#
# Deflater sits outside ErrorHandler so error responses are compressed too
# (see DECISIONS.md, decision 28), and the logger sits outside both so it
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
