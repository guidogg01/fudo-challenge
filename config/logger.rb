# frozen_string_literal: true

require "logger"
require "time"

# One JSON object per line, ready for a log store such as OpenSearch (decision 29).
JSON_LOG_FORMATTER = lambda do |severity, time, _progname, fields|
  "#{JSON.generate({ time: time.utc.iso8601(3), level: severity.downcase }.merge(fields))}\n"
end

# Without sync, Ruby buffers stdout when it is not a terminal (as in Docker)
# and log lines show up late.
$stdout.sync = true

LOGGER = Logger.new($stdout, level: ENV.fetch("LOG_LEVEL", "info"), formatter: JSON_LOG_FORMATTER)
