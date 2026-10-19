# frozen_string_literal: true

class User < Sequel::Model
  one_to_many :auth_tokens
  one_to_many :products
  one_to_many :product_requests
end
