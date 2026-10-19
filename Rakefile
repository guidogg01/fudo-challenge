# frozen_string_literal: true

MIGRATIONS_DIR = File.expand_path("db/migrations", __dir__)

namespace :db do
  desc "Run pending migrations (uses TEST_DATABASE_URL when RACK_ENV=test)"
  task :migrate do
    # Only the connection, not config/boot.rb: the models need the tables
    # that this task creates.
    require_relative "config/database"
    Sequel.extension :migration
    Sequel::Migrator.run(DB, MIGRATIONS_DIR)
    puts "Migrations up to date (#{DB.opts[:database]})"
  end

  desc "Create the demo user (safe to run more than once)"
  task :seed do
    require_relative "config/boot"
    load File.expand_path("db/seeds.rb", __dir__)
  end

  desc "Run migrations and seeds"
  task setup: %i[migrate seed]
end
