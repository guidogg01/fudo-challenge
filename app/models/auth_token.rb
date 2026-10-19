# frozen_string_literal: true

require "digest"

# Only the SHA-256 of a token is stored, never the token itself
# (decision 8).
class AuthToken < Sequel::Model
  many_to_one :user

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.find_active(token)
    where(token_digest: digest(token), revoked_at: nil).where(Sequel[:expires_at] > Time.now).first
  end

  def revoke!
    update(revoked_at: Time.now)
  end
end
