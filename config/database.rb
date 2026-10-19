# frozen_string_literal: true

require "sequel"

database_url_key = ENV.fetch("RACK_ENV", "development") == "test" ? "TEST_DATABASE_URL" : "DATABASE_URL"

Sequel.default_timezone = :utc

# One connection per Puma thread, so no request waits for a free connection.
DB = Sequel.connect(
  ENV.fetch(database_url_key),
  max_connections: Integer(ENV.fetch("PUMA_MAX_THREADS", 5))
)
DB.extension :pg_json
