# frozen_string_literal: true

module ProductSerializer
  def self.call(product)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      price_cents: product.price_cents,
      quantity: product.quantity,
      created_at: product.created_at.utc.iso8601,
      updated_at: product.updated_at.utc.iso8601
    }
  end
end
