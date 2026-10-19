# frozen_string_literal: true

# Rack::Files ya maneja Last-Modified e If-Modified-Since (304).
class AuthorsHandler
  PUBLIC_DIR = File.expand_path("../../public", __dir__)
  CACHE_CONTROL = "public, max-age=86400"

  def initialize
    @files = Rack::Files.new(PUBLIC_DIR, {}, "text/plain; charset=utf-8")
  end

  def call(request)
    status, headers, body = @files.call(request.env)
    # Se setea acá y no con la opción de headers de Rack::Files, que solo se
    # aplica al 200: un 304 también tiene que repetir la política de caché (RFC 9110, 15.4.5).
    headers["cache-control"] = CACHE_CONTROL
    [status, headers, body]
  end
end
