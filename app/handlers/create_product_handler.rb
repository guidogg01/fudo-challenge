# frozen_string_literal: true

# El 202 solo dice que la solicitud se registró, nunca que el producto existe (decisión 11).
class CreateProductHandler
  def call(request)
    attributes = ProductInput.validate!(request.json_body)
    product_request = RequestProductCreation.call(
      user: request.current_user, attributes: attributes, request_id: request.get_header(RequestId::ENV_KEY)
    )

    JsonResponse.build(
      202,
      { data: ProductRequestSerializer.call(product_request) },
      { "location" => "/product_requests/#{product_request.id}" }
    )
  end
end
