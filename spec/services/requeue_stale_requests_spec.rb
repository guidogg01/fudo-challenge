# frozen_string_literal: true

RSpec.describe RequeueStaleRequests do
  let(:user) { create_user }
  let(:old) { Time.now - 120 }

  def product_request(**attributes)
    ProductRequest.create(user_id: user.id, payload: Sequel.pg_jsonb({}), **attributes)
  end

  it "enqueues again only the requests pending for more than a minute" do
    stale = product_request(created_at: old)
    product_request(created_at: Time.now - 10)
    product_request(status: "failed", error_code: "creation_failed", created_at: old)
    product = Product.create(user_id: user.id, name: "Mesa", price_cents: 1, quantity: 1)
    product_request(status: "completed", product_id: product.id, created_at: old)

    expect(described_class.call).to eq(1)
    expect(CreateProductJob.jobs.map { |job| job["args"] }).to eq([[stale.id]])
  end

  it "logs how many requests it enqueued" do
    product_request(created_at: old)
    stub_const("LOGGER", test_logger)

    described_class.call

    expect(JSON.parse(log_output.string)).to include("event" => "stale_product_requests_requeued", "count" => 1)
  end
end
