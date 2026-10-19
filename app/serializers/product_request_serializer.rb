# frozen_string_literal: true

module ProductRequestSerializer
  def self.call(product_request)
    {
      id: product_request.id,
      status: product_request.status,
      product_id: product_request.product_id,
      product_url: product_request.product_id && "/products/#{product_request.product_id}",
      error: error(product_request),
      created_at: product_request.created_at.utc.iso8601,
      processed_at: product_request.processed_at&.utc&.iso8601
    }
  end

  def self.error(product_request)
    return nil unless product_request.error_code

    { code: product_request.error_code, message: product_request.error_message }
  end
  private_class_method :error
end
