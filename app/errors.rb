# frozen_string_literal: true

# ErrorHandler es el único lugar que convierte estos errores en respuestas HTTP
# (decisión 20). `code` es un identificador estable en inglés; `message` es
# texto en español para personas (decisión 21).
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
    # La misma respuesta si el usuario no existe o si la contraseña es incorrecta
    # (decisión 10).
    def initialize
      super(status: 401, code: "invalid_credentials", message: "Usuario o contraseña incorrectos.")
    end
  end

  class InvalidQuery < ApiError
    def initialize
      super(status: 400, code: "invalid_query", message: "Los parámetros de la URL no son válidos.")
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

  class NameAlreadyTaken < ApiError
    MESSAGE = "Ya tenés un producto con ese nombre."

    def initialize
      super(status: 409, code: "name_already_taken", message: MESSAGE)
    end
  end

  class PayloadTooLarge < ApiError
    def initialize(max_bytes)
      super(status: 413, code: "payload_too_large",
            message: "El cuerpo del request no puede superar los #{max_bytes / 1024} KB.")
    end
  end

  class ValidationFailed < ApiError
    def initialize(details)
      super(status: 422, code: "validation_failed", message: "Los datos enviados no son válidos.", details: details)
    end

    # issues: { "campo" => "issue" }; messages: { "campo" => { "issue" => "mensaje" } }.
    def self.from_issues(issues, messages)
      new(issues.map { |field, issue| { field: field, issue: issue, message: messages.fetch(field).fetch(issue) } })
    end
  end
end
