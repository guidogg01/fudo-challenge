# frozen_string_literal: true

max_threads = Integer(ENV.fetch("PUMA_MAX_THREADS", 5))
threads max_threads, max_threads

port Integer(ENV.fetch("PORT", 9292))
environment ENV.fetch("RACK_ENV", "development")
