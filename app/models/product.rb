# frozen_string_literal: true

class Product < Sequel::Model
  many_to_one :user
end
