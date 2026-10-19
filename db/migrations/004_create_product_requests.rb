# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:product_requests) do
      # A random UUID, so request ids cannot be guessed (decision 22).
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
      foreign_key :user_id, :users, type: :Bignum, null: false, index: true
      String :status, text: true, null: false, default: "pending"
      jsonb :payload, null: false
      foreign_key :product_id, :products, type: :Bignum, unique: true
      String :error_code, text: true
      String :error_message, text: true
      column :processed_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      # Finds old pending requests when the worker starts (decision 30).
      index %i[status created_at]

      constraint(:product_requests_status_check,
                 Sequel.lit("status IN ('pending', 'completed', 'failed')"))
      constraint(:product_requests_completed_check,
                 Sequel.lit("(status = 'completed') = (product_id IS NOT NULL)"))
    end
  end
end
