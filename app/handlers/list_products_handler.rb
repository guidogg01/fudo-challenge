# frozen_string_literal: true

class ListProductsHandler
  def call(request)
    params = Pagination.parse(request.query_params)
    products = Product.where(user_id: request.current_user.id)
    total = products.count
    data = page_of(products, params, total).map { |product| ProductSerializer.call(product) }

    JsonResponse.build(200, { data: data, meta: Pagination.meta(params, total) })
  end

  private

  # Una página fuera de rango da data vacía sin consultar: un OFFSET enorme
  # desbordaría el bigint de PostgreSQL y terminaría en un 500.
  def page_of(products, params, total)
    return [] if params.offset >= total

    products.order(:id).limit(params.per_page, params.offset).all
  end
end
