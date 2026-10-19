# frozen_string_literal: true

# Errors the API reports to the client. Code anywhere in the app raises one
# of these, and ErrorHandler is the only place that turns it into an HTTP
# response (see DECISIONS.md, decision 20). `code` is a stable identifier in
# English; `message` is Spanish text for people (decision 21).
class ApiError < StandardError
  attr_reader :status, :code, :details, :headers

  def initialize(status:, code:, message:, details: [], headers: {})
    super(message)
    @status = status
    @code = code
    @details = details
    @headers = headers
  end

  class InvalidJson < ApiError
    def initialize(message = "El cuerpo del request no es un JSON válido.")
      super(status: 400, code: "invalid_json", message: message)
    end
  end

  class Unauthorized < ApiError
    def initialize
      super(status: 401, code: "unauthorized", message: "Necesitás un token válido para acceder.")
    end
  end

  class NotFound < ApiError
    def initialize
      super(status: 404, code: "not_found", message: "No se encontró el recurso.")
    end
  end

  class MethodNotAllowed < ApiError
    # The Allow header tells the client which methods the path does accept.
    def initialize(allowed_methods)
      super(
        status: 405,
        code: "method_not_allowed",
        message: "El método HTTP no está permitido para esta ruta.",
        headers: { "allow" => allowed_methods.join(", ") }
      )
    end
  end

  class UnsupportedMediaType < ApiError
    def initialize
      super(status: 415, code: "unsupported_media_type", message: "El Content-Type debe ser application/json.")
    end
  end
end
