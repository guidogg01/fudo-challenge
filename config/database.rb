# frozen_string_literal: true

require "sequel"

# Tests use their own database so that running the suite never touches
# development data (see DECISIONS.md, decision 6).
database_url_key = ENV.fetch("RACK_ENV", "development") == "test" ? "TEST_DATABASE_URL" : "DATABASE_URL"

# Timestamps are stored and read as UTC, whatever the server's time zone is.
Sequel.default_timezone = :utc

# One connection per Puma thread, so no request waits for a free connection.
DB = Sequel.connect(
  ENV.fetch(database_url_key),
  max_connections: Integer(ENV.fetch("PUMA_MAX_THREADS", 5))
)
DB.extension :pg_json
