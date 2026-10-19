# frozen_string_literal: true

class LoginHandler
  def call(request)
    credentials = LoginInput.validate!(request.json_body)
    result = Login.call(credentials["username"], credentials["password"])
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
end
