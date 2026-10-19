# frozen_string_literal: true

RSpec.describe CreateProductJob do
  let(:user) { create_user }

  before { stub_const("LOGGER", test_logger) }

  def pending_request(name: "Mesa", for_user: user)
    ProductRequest.create(
      user_id: for_user.id,
      payload: Sequel.pg_jsonb("name" => name, "description" => "Roble", "price_cents" => 150_000, "quantity" => 3)
    )
  end

  def capturing_sql
    sql_log = StringIO.new
    sql_logger = Logger.new(sql_log)
    DB.loggers << sql_logger
    yield
    sql_log.string
  ensure
    DB.loggers.delete(sql_logger)
  end

  it "creates the product from the payload and completes the request" do
    product_request = pending_request

    described_class.new.perform(product_request.id, "req-1")

    expect(Product.first.values).to include(
      user_id: user.id, name: "Mesa", description: "Roble", price_cents: 150_000, quantity: 3
    )
    expect(product_request.refresh.values).to include(status: "completed", product_id: Product.first.id)
    expect(product_request.processed_at).not_to be_nil
  end

  it "logs product_created with the request id" do
    described_class.new.perform(pending_request.id, "req-1")

    expect(log_events.last).to include("event" => "product_created", "request_id" => "req-1", "user_id" => user.id)
  end

  it "does nothing when it runs again for the same request (idempotent)" do
    product_request = pending_request

    2.times { described_class.new.perform(product_request.id) }

    expect(Product.count).to eq(1)
    expect(log_events.last).to include("event" => "product_request_skipped", "status" => "completed")
  end

  # El lock es lo que hace seguras dos ejecuciones simultáneas (decisión 13).
  it "locks the request row with SELECT ... FOR UPDATE before creating the product" do
    product_request = pending_request

    sql = capturing_sql { described_class.new.perform(product_request.id) }

    expect(sql).to match(/FROM "product_requests" WHERE .* FOR UPDATE/)
  end

  it "does nothing, with a warning, when the request does not exist" do
    expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error

    expect(Product.count).to eq(0)
    expect(log_events.last).to include("level" => "warn", "event" => "product_request_not_found")
  end

  describe "two requests with the same name" do
    let(:first_request) { pending_request(name: "Mesa") }
    let(:second_request) { pending_request(name: "MESA") }

    it "completes the first and fails the second with name_already_taken" do
      [first_request, second_request].each { |product_request| described_class.new.perform(product_request.id) }

      expect(first_request.refresh.status).to eq("completed")
      expect(second_request.refresh.values).to include(
        status: "failed", error_code: "name_already_taken", error_message: "Ya tenés un producto con ese nombre."
      )
      expect(Product.count).to eq(1)
    end

    it "logs the failure as a warning" do
      described_class.new.perform(pending_request(name: "Mesa").id)
      described_class.new.perform(pending_request(name: "Mesa").id, "req-2")

      expect(log_events.last).to include(
        "level" => "warn", "event" => "product_creation_failed", "reason" => "name_already_taken",
        "request_id" => "req-2"
      )
    end
  end

  it "lets unexpected errors raise, so Sidekiq retries them" do
    product_request = pending_request
    allow(Product).to receive(:create).and_raise(Sequel::DatabaseConnectionError)

    expect { described_class.new.perform(product_request.id) }.to raise_error(Sequel::DatabaseConnectionError)
    expect(product_request.refresh.status).to eq("pending")
  end

  it "retries at most 5 times" do
    expect(described_class.get_sidekiq_options["retry"]).to eq(5)
  end

  describe "when the retries run out" do
    def exhaust_retries(product_request)
      described_class.sidekiq_retries_exhausted_block.call(
        { "args" => [product_request.id, "req-3"] }, Sequel::DatabaseConnectionError.new("db down")
      )
    end

    it "fails the request with creation_failed" do
      product_request = pending_request

      exhaust_retries(product_request)

      expect(product_request.refresh.values).to include(
        status: "failed", error_code: "creation_failed", error_message: "No se pudo crear el producto."
      )
    end

    it "logs the error" do
      exhaust_retries(pending_request)

      expect(log_events.last).to include(
        "level" => "error", "reason" => "creation_failed", "error_class" => "Sequel::DatabaseConnectionError"
      )
    end

    it "leaves a request that already completed untouched" do
      product_request = pending_request
      described_class.new.perform(product_request.id)

      exhaust_retries(product_request)

      expect(product_request.refresh.status).to eq("completed")
    end
  end
end
