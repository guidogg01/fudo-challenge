# frozen_string_literal: true

# Finds the token behind an "Authorization: Bearer <token>" header. Missing,
# malformed, unknown, expired and revoked tokens all get the same 401, so
# the response says nothing about which one it was.
module TokenAuthentication
  # The scheme name is case-insensitive in HTTP (RFC 7235, section 2.1),
  # so "bearer <token>" works too.
  BEARER = /\ABearer +(\S+)\z/i

  def self.call(authorization_header)
    match = BEARER.match(authorization_header.to_s)
    auth_token = match && AuthToken.find_active(match[1])
    raise ApiError::Unauthorized unless auth_token

    auth_token
  end
end
