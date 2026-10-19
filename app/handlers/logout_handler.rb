# frozen_string_literal: true

# POST /auth/logout. Revokes the token used in this same request: from now
# on it gets 401, even before it expires (see DECISIONS.md, decision 8).
class LogoutHandler
  def call(request)
    request.auth_token.revoke!
    [204, {}, []]
  end
end
