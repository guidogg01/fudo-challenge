# frozen_string_literal: true

# Demo data for trying the API by hand. Running it again changes nothing.

username = "demo"
password = "demo1234"

if User.where(Sequel.function(:lower, :username) => username).empty?
  User.create(
    username: username,
    password_digest: BCrypt::Password.create(password, cost: Integer(ENV.fetch("BCRYPT_COST", 12)))
  )
  puts "Created user #{username}"
else
  puts "User #{username} already exists"
end
