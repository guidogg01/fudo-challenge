# frozen_string_literal: true

require "sequel"

database_url_key = ENV.fetch("RACK_ENV", "development") == "test" ? "TEST_DATABASE_URL" : "DATABASE_URL"

Sequel.default_timezone = :utc

# Una conexión por thread de Puma; el worker usa la misma cantidad de threads (config/sidekiq.rb).
# Sin los timeouts, una base que deja de responder (una partición de red) deja
# colgado al request por minutos: connect_timeout corta las conexiones nuevas y
# tcp_user_timeout (milisegundos, de libpq) las que ya están abiertas.
DB = Sequel.connect(
  ENV.fetch(database_url_key),
  max_connections: Integer(ENV.fetch("PUMA_MAX_THREADS", 5)),
  connect_timeout: 2,
  driver_options: { tcp_user_timeout: 2000 }
)
DB.extension :pg_json
