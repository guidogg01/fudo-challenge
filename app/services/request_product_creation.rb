# frozen_string_literal: true

module RequestProductCreation
  CREATION_DELAY_SECONDS = 5

  def self.call(user:, attributes:, request_id:)
    # Es solo un aviso temprano, no la garantía: dos solicitudes pueden pasar este
    # chequeo a la vez, y después decide el índice único en el job (decisión 15).
    raise ApiError::NameAlreadyTaken if name_taken?(user, attributes["name"])

    # Guardar la solicitud y encolar el job van en una sola transacción: si
    # Redis falla, la solicitud se deshace y el cliente recibe un 500
    # en vez de una solicitud que quedaría pending para siempre.
    DB.transaction do
      product_request = ProductRequest.create(user_id: user.id, payload: Sequel.pg_jsonb(attributes))
      CreateProductJob.perform_in(CREATION_DELAY_SECONDS, product_request.id, request_id)
      product_request
    end
  end

  def self.name_taken?(user, name)
    !Product.where(user_id: user.id, Sequel.function(:lower, :name) => Sequel.function(:lower, name)).empty?
  end
  private_class_method :name_taken?
end
