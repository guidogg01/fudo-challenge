# frozen_string_literal: true

# Reads the body of a request that must carry a JSON object
# (see DECISIONS.md, decision 24): wrong Content-Type -> 415, body that is
# not JSON or not an object -> 400. Checking the fields is the handler's job (422).
module JsonBody
  def self.parse(request)
    # media_type ignores parameters, so "application/json; charset=utf-8" is accepted.
    raise ApiError::UnsupportedMediaType unless request.media_type == "application/json"

    # Rack 3 allows requests without an input stream at all.
    parsed = JSON.parse(request.body&.read || "")
    raise ApiError::InvalidJson, "El cuerpo del request debe ser un objeto JSON." unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError
    raise ApiError::InvalidJson
  end
end
