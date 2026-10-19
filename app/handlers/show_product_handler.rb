# frozen_string_literal: true

# Un producto de otro usuario responde 404, igual que uno inexistente (decisión 22).
class ShowProductHandler
  # Hasta 18 dígitos entra siempre en un bigint; algo más largo o que no sea un
  # número haría fallar la consulta con un 500, así que nunca llega a la base.
  ID = /\A[1-9]\d{0,17}\z/

  def call(request)
    id = request.path_params[:id]
    raise ApiError::NotFound unless id.match?(ID)

    product = Product.first(id: Integer(id, 10), user_id: request.current_user.id)
    raise ApiError::NotFound unless product

    JsonResponse.build(200, { data: ProductSerializer.call(product) })
  end
end
