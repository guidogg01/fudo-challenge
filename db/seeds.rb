# frozen_string_literal: true

# Demo data for trying the API by hand. Running it again changes nothing.

username = "demo"
password = "demo1234"

if User.find_by_username(username).nil?
  User.create(
    username: username,
    password_digest: User.digest_password(password)
  )
  puts "Created user #{username}"
else
  puts "User #{username} already exists"
end
