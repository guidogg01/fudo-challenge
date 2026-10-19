# frozen_string_literal: true

require "logger"
require "time"

# Un objeto JSON por línea, listo para un almacén de logs como OpenSearch (decisión 29).
JSON_LOG_FORMATTER = lambda do |severity, time, _progname, fields|
  "#{JSON.generate({ time: time.utc.iso8601(3), level: severity.downcase }.merge(fields))}\n"
end

# Sin sync, Ruby acumula stdout cuando no es una terminal (como en Docker)
# y las líneas del log aparecen tarde.
$stdout.sync = true

LOGGER = Logger.new($stdout, level: ENV.fetch("LOG_LEVEL", "info"), formatter: JSON_LOG_FORMATTER)
