# frozen_string_literal: true

# Token ausente, mal formado, inexistente, vencido o revocado: todos reciben el mismo
# 401, así la respuesta no revela cuál de los casos fue.
module TokenAuthentication
  # El nombre del esquema no distingue mayúsculas (RFC 7235, sección 2.1).
  BEARER = /\ABearer +(\S+)\z/i

  def self.call(authorization_header)
    match = BEARER.match(authorization_header.to_s)
    auth_token = match && AuthToken.find_active(match[1])
    raise ApiError::Unauthorized unless auth_token

    auth_token
  end
end
