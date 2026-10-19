# frozen_string_literal: true

class User < Sequel::Model
  # bcrypt work factor: each +1 doubles the time to hash a password
  # (see DECISIONS.md, decision 7).
  BCRYPT_COST = Integer(ENV.fetch("BCRYPT_COST", 12))

  one_to_many :auth_tokens
  one_to_many :products
  one_to_many :product_requests

  def self.digest_password(password)
    BCrypt::Password.create(password, cost: BCRYPT_COST).to_s
  end

  # "Demo" and "demo" are the same user, as the unique index on
  # lower(username) says (see DECISIONS.md, decision 16).
  def self.find_by_username(username)
    where(Sequel.function(:lower, :username) => Sequel.function(:lower, username)).first
  end
end
