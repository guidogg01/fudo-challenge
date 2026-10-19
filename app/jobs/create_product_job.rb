# frozen_string_literal: true

# Sidekiq entrega cada job al menos una vez: correrlo dos veces, incluso al mismo
# tiempo, tiene que tener el mismo efecto que correrlo una (decisiones 13 y 14).
class CreateProductJob
  include Sidekiq::Job

  # Los 25 reintentos por defecto duran unos 21 días; una creación que el usuario
  # espera en segundos tiene que fallar definitivamente en minutos.
  sidekiq_options retry: 5

  sidekiq_retries_exhausted do |job, error|
    product_request_id, request_id = job["args"]
    CreateProductJob.mark_failed(product_request_id, "creation_failed", request_id: request_id, error: error)
  end

  FAILURE_MESSAGES = {
    "name_already_taken" => ApiError::NameAlreadyTaken::MESSAGE,
    "creation_failed" => "No se pudo crear el producto."
  }.freeze

  def perform(product_request_id, request_id = nil)
    product = DB.transaction do
      product_request = lock_pending(product_request_id, request_id)
      next unless product_request

      create_product(product_request)
    end
    log_created(product, product_request_id, request_id) if product
  rescue Sequel::UniqueConstraintViolation
    # Es un fallo de negocio, así que no se reintenta (decisión 14).
    self.class.mark_failed(product_request_id, "name_already_taken", request_id: request_id)
  end

  # Marca la solicitud como failed en su propia transacción, y solo si sigue
  # pending, para no pisar nunca una solicitud que sí se completó.
  def self.mark_failed(product_request_id, code, request_id:, error: nil)
    marked = DB.transaction do
      product_request = ProductRequest.where(id: product_request_id).for_update.first
      next unless product_request&.status == "pending"

      product_request.update(
        status: "failed", error_code: code, error_message: FAILURE_MESSAGES.fetch(code), processed_at: Time.now
      )
      true
    end
    log_failed(product_request_id, code, request_id, error) if marked
  end

  def self.log_failed(product_request_id, code, request_id, error)
    fields = { event: "product_creation_failed", product_request_id: product_request_id, reason: code,
               request_id: request_id }
    if error
      LOGGER.error(**fields, error_class: error.class.name, error_message: error.message)
    else
      LOGGER.warn(**fields)
    end
  end
  private_class_method :log_failed

  private

  # SELECT ... FOR UPDATE: una segunda ejecución del mismo job espera acá a que
  # la primera haga commit, y después ve que la solicitud ya no está pending.
  def lock_pending(product_request_id, request_id)
    product_request = ProductRequest.where(id: product_request_id).for_update.first
    return product_request if product_request&.status == "pending"

    log_not_processed(product_request_id, product_request, request_id)
    nil
  end

  def log_not_processed(product_request_id, product_request, request_id)
    if product_request
      LOGGER.info(event: "product_request_skipped", product_request_id: product_request_id,
                  status: product_request.status, request_id: request_id)
    else
      # No debería pasar: la solicitud se guarda en la misma transacción que
      # encola el job. Es un warning porque nada lo va a reintentar.
      LOGGER.warn(event: "product_request_not_found", product_request_id: product_request_id, request_id: request_id)
    end
  end

  def create_product(product_request)
    payload = product_request.payload
    product = Product.create(
      user_id: product_request.user_id,
      name: payload["name"],
      description: payload["description"],
      price_cents: payload["price_cents"],
      quantity: payload["quantity"]
    )
    product_request.update(status: "completed", product_id: product.id, processed_at: Time.now)
    product
  end

  def log_created(product, product_request_id, request_id)
    LOGGER.info(event: "product_created", product_request_id: product_request_id, product_id: product.id,
                user_id: product.user_id, request_id: request_id)
  end
end
