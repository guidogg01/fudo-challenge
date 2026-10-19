# frozen_string_literal: true

require_relative "config/boot"

run Application.build(ROUTES)
