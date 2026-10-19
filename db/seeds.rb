# frozen_string_literal: true

# Datos de demo para probar la API a mano. Correrlo de nuevo no cambia nada.

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
