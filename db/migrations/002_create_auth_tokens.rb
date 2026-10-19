# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:auth_tokens) do
      primary_key :id, type: :Bignum
      foreign_key :user_id, :users, type: :Bignum, null: false, on_delete: :cascade, index: true
      # Only the SHA-256 of the token is stored, never the token itself
      # (see DECISIONS.md, decision 8).
      String :token_digest, text: true, null: false, unique: true
      column :expires_at, :timestamptz, null: false
      column :revoked_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
