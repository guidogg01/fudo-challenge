# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:auth_tokens) do
      primary_key :id, type: :Bignum
      foreign_key :user_id, :users, type: :Bignum, null: false, on_delete: :cascade, index: true
      String :token_digest, text: true, null: false, unique: true
      column :expires_at, :timestamptz, null: false
      column :revoked_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
