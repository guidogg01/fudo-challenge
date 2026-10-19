# frozen_string_literal: true

# La solicitud de otro usuario responde 404, igual que una inexistente (decisión 22).
class ProductRequestHandler
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  def call(request)
    id = request.path_params[:id]
    # PostgreSQL rechazaría con un 500 un id que no es UUID, así que nunca llega a la base.
    raise ApiError::NotFound unless id.match?(UUID)

    product_request = ProductRequest.first(id: id, user_id: request.current_user.id)
    raise ApiError::NotFound unless product_request

    JsonResponse.build(200, { data: ProductRequestSerializer.call(product_request) })
  end
end
