# frozen_string_literal: true

require "logger"
require "time"

# Logs go to stdout as one JSON object per line, ready to be shipped to a
# log store such as OpenSearch without parsing (see DECISIONS.md, decision 29).
# Callers pass a hash of fields: LOGGER.info(event: "request", status: 200).
JSON_LOG_FORMATTER = lambda do |severity, time, _progname, fields|
  "#{JSON.generate({ time: time.utc.iso8601(3), level: severity.downcase }.merge(fields))}\n"
end

# Without sync, Ruby buffers stdout when it is not a terminal (as in Docker)
# and log lines show up late.
$stdout.sync = true

LOGGER = Logger.new($stdout, level: ENV.fetch("LOG_LEVEL", "info"), formatter: JSON_LOG_FORMATTER)
