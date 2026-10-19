# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id, type: :Bignum
      String :username, text: true, null: false
      String :password_digest, text: true, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index Sequel.function(:lower, :username), unique: true, name: :users_lower_username_index
    end
  end
end
