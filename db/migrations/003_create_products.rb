# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:products) do
      primary_key :id, type: :Bignum
      foreign_key :user_id, :users, type: :Bignum, null: false
      String :name, text: true, null: false
      String :description, text: true
      # Money is an integer number of cents, never a float (see DECISIONS.md, decision 18).
      Bignum :price_cents, null: false
      Integer :quantity, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      # The guarantee that a user cannot have two products with the same name,
      # ignoring case. It also serves queries that filter by user_id, because
      # user_id is its first column (see DECISIONS.md, decision 16).
      index [:user_id, Sequel.function(:lower, :name)], unique: true, name: :products_user_id_lower_name_index

      # Second line of defense behind the app's validations (see DECISIONS.md, decision 19).
      constraint(:products_name_length_check, Sequel.lit("char_length(name) BETWEEN 1 AND 100"))
      constraint(:products_description_length_check,
                 Sequel.lit("description IS NULL OR char_length(description) <= 500"))
      constraint(:products_price_cents_check, Sequel.lit("price_cents >= 0"))
      constraint(:products_quantity_check, Sequel.lit("quantity >= 0"))
    end
  end
end
