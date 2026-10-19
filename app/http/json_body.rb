# frozen_string_literal: true

module JsonBody
  # Los bodies de la API son de pocos cientos de bytes; el tope evita que un
  # request público, como el login, obligue a leer megas a memoria.
  MAX_BYTES = 16 * 1024

  def self.parse(request)
    # media_type ignora los parámetros, así que acepta "application/json; charset=utf-8".
    raise ApiError::UnsupportedMediaType unless request.media_type == "application/json"

    parsed = JSON.parse(read_utf8(request))
    raise ApiError::InvalidJson, "El cuerpo del request debe ser un objeto JSON." unless parsed.is_a?(Hash)
    # "\u0000" es JSON válido, pero el text de PostgreSQL no lo puede guardar y la
    # consulta fallaría con un 500.
    raise ApiError::InvalidJson, "El cuerpo del request no puede contener el carácter nulo." if contains_nul?(parsed)

    parsed
  # JSON::NestingError (demasiado anidado) también es un ParserError.
  rescue JSON::ParserError
    raise ApiError::InvalidJson
  end

  # JSON tiene que ser UTF-8 (RFC 8259). JSON.parse acepta bytes inválidos, que
  # después fallarían en algún lugar de la app con un 500.
  def self.read_utf8(request)
    raise ApiError::PayloadTooLarge, MAX_BYTES if request.content_length.to_i > MAX_BYTES

    # Lee un byte de más para detectar un body sin Content-Length que supere el tope.
    # Rack 3 permite requests sin ningún stream de entrada.
    raw = String.new(request.body&.read(MAX_BYTES + 1).to_s, encoding: Encoding::UTF_8)
    raise ApiError::PayloadTooLarge, MAX_BYTES if raw.bytesize > MAX_BYTES
    raise ApiError::InvalidJson unless raw.valid_encoding?

    raw
  end

  def self.contains_nul?(value)
    case value
    when String then value.include?("\u0000")
    when Hash then value.any? { |key, item| contains_nul?(key) || contains_nul?(item) }
    when Array then value.any? { |item| contains_nul?(item) }
    else false
    end
  end

  private_class_method :read_utf8, :contains_nul?
end
