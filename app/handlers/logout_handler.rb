# frozen_string_literal: true

class LogoutHandler
  def call(request)
    request.auth_token.revoke!
    [204, {}, []]
  end
end
