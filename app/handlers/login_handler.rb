# frozen_string_literal: true

class LoginHandler
  MESSAGES = {
    "username" => {
      "required" => "El usuario es obligatorio.",
      "invalid_type" => "El usuario debe ser un texto.",
      "blank" => "El usuario no puede estar vacío."
    },
    "password" => {
      "required" => "La contraseña es obligatoria.",
      "invalid_type" => "La contraseña debe ser un texto.",
      "blank" => "La contraseña no puede estar vacía."
    }
  }.freeze

  def call(request)
    body = request.json_body
    validate!(body)

    result = Login.call(body["username"], body["password"])
    # Login es una ruta pública, así que el router no setea usuario; este es solo
    # para el log del request.
    request.current_user = result.user

    JsonResponse.build(
      200,
      { data: { token: result.token, token_type: "Bearer", expires_at: result.expires_at.utc.iso8601 } },
      # Ni el navegador ni un proxy tienen que guardar el token.
      { "cache-control" => "no-store" }
    )
  end

  private

  def validate!(body)
    details = MESSAGES.keys.filter_map do |field|
      issue = issue_for(body[field])
      { field: field, issue: issue, message: MESSAGES[field][issue] } if issue
    end
    raise ApiError::ValidationFailed, details if details.any?
  end

  def issue_for(value)
    if value.nil? then "required"
    elsif !value.is_a?(String) then "invalid_type"
    elsif value.strip.empty? then "blank"
    end
  end
end
