# frozen_string_literal: true

class ProductRequest < Sequel::Model
  many_to_one :user
  many_to_one :product
end
