# frozen_string_literal: true

# Rack::Files already handles Last-Modified and If-Modified-Since (304).
class AuthorsHandler
  PUBLIC_DIR = File.expand_path("../../public", __dir__)
  CACHE_CONTROL = "public, max-age=86400"

  def initialize
    @files = Rack::Files.new(PUBLIC_DIR, {}, "text/plain; charset=utf-8")
  end

  def call(request)
    status, headers, body = @files.call(request.env)
    # Set here and not through Rack::Files' headers option, which only
    # applies to 200: a 304 must repeat the cache policy too (RFC 9110, 15.4.5).
    headers["cache-control"] = CACHE_CONTROL
    [status, headers, body]
  end
end
