# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:product_requests) do
      # Igual que "completed ⇔ product_id": una solicitud falla exactamente cuando tiene motivo (decisión 19).
      add_constraint(:product_requests_failed_check, Sequel.lit("(status = 'failed') = (error_code IS NOT NULL)"))
    end
  end
end
