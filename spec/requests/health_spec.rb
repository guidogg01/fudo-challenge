# frozen_string_literal: true

RSpec.describe "GET /health", type: :request do
  it "responds 200 when PostgreSQL and Redis answer" do
    get "/health"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to eq("application/json")
    expect(json_body).to eq("status" => "ok", "checks" => { "database" => "ok", "redis" => "ok" })
  end

  it "logs which dependency failed, with the request id" do
    allow(DB).to receive(:get).and_raise(Sequel::DatabaseConnectionError)
    stub_const("LOGGER", test_logger)

    get "/health", {}, "HTTP_X_REQUEST_ID" => "health-1"

    expect(log_events.first).to include(
      "level" => "warn", "event" => "health_check_failed", "dependency" => "database", "request_id" => "health-1"
    )
  end

  it "responds 503 and names the database when PostgreSQL fails" do
    allow(DB).to receive(:get).and_raise(Sequel::DatabaseConnectionError)

    get "/health"

    expect(last_response.status).to eq(503)
    expect(json_body).to eq("status" => "error", "checks" => { "database" => "error", "redis" => "ok" })
  end

  it "responds 503 and names Redis when Redis fails" do
    allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)

    get "/health"

    expect(last_response.status).to eq(503)
    expect(json_body).to eq("status" => "error", "checks" => { "database" => "ok", "redis" => "error" })
  end

  it "answers HEAD with the status and no body, for monitors" do
    head "/health"

    expect(last_response.status).to eq(200)
    expect(last_response.body).to be_empty
  end
end
