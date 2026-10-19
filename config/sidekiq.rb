# frozen_string_literal: true

# Solo corre dentro del proceso worker (bundle exec sidekiq), no en Puma.
Sidekiq.configure_server do |config|
  # Los jobs programados se revisan cada 0,5x a 1,5x esta cantidad de segundos, así
  # que un producto aparece entre 5 y unos 6,5 segundos después del pedido (decisión 12).
  config.average_scheduled_poll_interval = 1

  # Un thread del worker por conexión del pool, así ningún job espera una conexión libre.
  config.concurrency = DB.pool.max_size

  config.on(:startup) { RequeueStaleRequests.call }
end
