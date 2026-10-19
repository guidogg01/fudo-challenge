# frozen_string_literal: true

# Red de seguridad: Sidekiq gratuito pierde el job en curso si el worker se cae de golpe.
# Encolar dos veces una solicitud no hace daño porque el job es idempotente (decisión 30).
module RequeueStaleRequests
  STALE_AFTER_SECONDS = 60

  def self.call
    ids = ProductRequest.where(status: "pending")
                        .where(Sequel[:created_at] < Time.now - STALE_AFTER_SECONDS)
                        .select_map(:id)
    ids.each { |id| CreateProductJob.perform_async(id) }
    LOGGER.info(event: "stale_product_requests_requeued", count: ids.size) if ids.any?
    ids.size
  end
end
