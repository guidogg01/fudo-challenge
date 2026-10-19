# frozen_string_literal: true

module JsonBody
  def self.parse(request)
    # media_type ignores parameters, so "application/json; charset=utf-8" is accepted.
    raise ApiError::UnsupportedMediaType unless request.media_type == "application/json"

    parsed = JSON.parse(read_utf8(request))
    raise ApiError::InvalidJson, "El cuerpo del request debe ser un objeto JSON." unless parsed.is_a?(Hash)
    # "\u0000" is valid JSON, but PostgreSQL text cannot store it and the
    # query would fail as a 500.
    raise ApiError::InvalidJson, "El cuerpo del request no puede contener el carácter nulo." if contains_nul?(parsed)

    parsed
  # JSON::NestingError (too deeply nested) is a ParserError too.
  rescue JSON::ParserError
    raise ApiError::InvalidJson
  end

  # JSON must be UTF-8 (RFC 8259). JSON.parse accepts invalid bytes, which
  # would then fail deep inside the app as a 500.
  def self.read_utf8(request)
    # Rack 3 allows requests without an input stream at all.
    raw = String.new(request.body&.read.to_s, encoding: Encoding::UTF_8)
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
