# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:product_requests) do
      # A random UUID, so request ids cannot be guessed (see DECISIONS.md, decision 22).
      # gen_random_uuid() is built into PostgreSQL since version 13.
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
      foreign_key :user_id, :users, type: :Bignum, null: false, index: true
      String :status, text: true, null: false, default: "pending"
      # What the user asked for, already validated (see DECISIONS.md, decision 17).
      jsonb :payload, null: false
      # Unique: one request creates at most one product.
      foreign_key :product_id, :products, type: :Bignum, unique: true
      String :error_code, text: true
      String :error_message, text: true
      column :processed_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      # Finds old pending requests when the worker starts (see DECISIONS.md, decision 30).
      index %i[status created_at]

      constraint(:product_requests_status_check,
                 Sequel.lit("status IN ('pending', 'completed', 'failed')"))
      # A request is completed exactly when it has a product.
      constraint(:product_requests_completed_check,
                 Sequel.lit("(status = 'completed') = (product_id IS NOT NULL)"))
    end
  end
end
