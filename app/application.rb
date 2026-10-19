# frozen_string_literal: true

require "rack/builder"
require "rack/deflater"

# El orden importa: Deflater va afuera de ErrorHandler para que las respuestas
# de error también se compriman (decisión 28), y el logger va afuera de ambos
# para ver el status final de cada request.
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
