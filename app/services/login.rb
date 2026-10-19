# frozen_string_literal: true

require "securerandom"

# Checks a username and password and, if they match, issues a new token
# (see DECISIONS.md, decisions 7, 8 and 10).
module Login
  TOKEN_TTL_SECONDS = Integer(ENV.fetch("TOKEN_TTL_SECONDS", 86_400))

  # Used when the username does not exist, so a failed login runs bcrypt
  # just like a wrong password does and both take the same time.
  DUMMY_PASSWORD_DIGEST = User.digest_password(SecureRandom.hex(16))

  Result = Data.define(:token, :user, :expires_at)

  # Returns a Result with the token in clear text, the only time it exists
  # outside the client. Raises ApiError::InvalidCredentials otherwise.
  def self.call(username, password)
    user = User.find_by_username(username)
    password_matches = BCrypt::Password.new(user&.password_digest || DUMMY_PASSWORD_DIGEST) == password
    raise ApiError::InvalidCredentials unless user && password_matches

    issue_token(user)
  end

  # 32 random bytes cannot be guessed, so a fast hash such as SHA-256 is
  # enough to protect them at rest, unlike a password.
  def self.issue_token(user)
    token = SecureRandom.urlsafe_base64(32)
    auth_token = AuthToken.create(
      user_id: user.id,
      token_digest: AuthToken.digest(token),
      expires_at: Time.now + TOKEN_TTL_SECONDS
    )
    Result.new(token: token, user: user, expires_at: auth_token.expires_at)
  end
  private_class_method :issue_token
end
