# frozen_string_literal: true

class User < Sequel::Model
  BCRYPT_COST = Integer(ENV.fetch("BCRYPT_COST", 12))

  one_to_many :auth_tokens
  one_to_many :products
  one_to_many :product_requests

  def self.digest_password(password)
    BCrypt::Password.create(password, cost: BCRYPT_COST).to_s
  end

  # Case-insensitive, like the unique index on lower(username) (decision 16).
  def self.find_by_username(username)
    where(Sequel.function(:lower, :username) => Sequel.function(:lower, username)).first
  end
end
