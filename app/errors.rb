# frozen_string_literal: true

# ErrorHandler is the only place that turns these into HTTP responses
# (decision 20). `code` is a stable English identifier; `message` is
# Spanish text for people (decision 21).
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

  class InvalidCredentials < ApiError
    # The same answer whether the user does not exist or the password is wrong
    # (decision 10).
    def initialize
      super(status: 401, code: "invalid_credentials", message: "Usuario o contraseña incorrectos.")
    end
  end

  class NotFound < ApiError
    def initialize
      super(status: 404, code: "not_found", message: "No se encontró el recurso.")
    end
  end

  class MethodNotAllowed < ApiError
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

  class ValidationFailed < ApiError
    def initialize(details)
      super(status: 422, code: "validation_failed", message: "Los datos enviados no son válidos.", details: details)
    end
  end
end
