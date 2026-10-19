# frozen_string_literal: true

require "securerandom"

module Login
  TOKEN_TTL_SECONDS = Integer(ENV.fetch("TOKEN_TTL_SECONDS", 86_400))

  # Se usa cuando el usuario no existe, para que un login fallido corra bcrypt
  # igual que con una contraseña incorrecta y los dos tarden lo mismo.
  DUMMY_PASSWORD_DIGEST = User.digest_password(SecureRandom.hex(16))

  Result = Data.define(:token, :user, :expires_at)

  # El único momento en que el token existe en claro fuera del cliente.
  def self.call(username, password)
    user = User.find_by_username(username)
    password_matches = BCrypt::Password.new(user&.password_digest || DUMMY_PASSWORD_DIGEST) == password
    raise ApiError::InvalidCredentials unless user && password_matches

    issue_token(user)
  end

  # 32 bytes al azar no se pueden adivinar, así que un hash rápido como SHA-256
  # alcanza para protegerlos en la base, a diferencia de una contraseña.
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
