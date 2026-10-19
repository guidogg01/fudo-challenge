# frozen_string_literal: true

require "stringio"

module UserHelpers
  def create_user(username = "ana", password: "secreto123")
    User.create(username: username, password_digest: User.digest_password(password))
  end

  # Devuelve el token en claro; en la base queda solo su SHA-256, como en el login real.
  def issue_token(user, expires_at: Time.now + 60, revoked_at: nil)
    token = SecureRandom.hex(16)
    AuthToken.create(user_id: user.id, token_digest: AuthToken.digest(token), expires_at: expires_at,
                     revoked_at: revoked_at)
    token
  end

  def authorization_for(user)
    "Bearer #{issue_token(user)}"
  end
end

module LogHelpers
  def log_output
    @log_output ||= StringIO.new
  end

  def test_logger
    Logger.new(log_output, formatter: JSON_LOG_FORMATTER)
  end

  def log_events
    log_output.string.lines.map { |line| JSON.parse(line) }
  end
end
