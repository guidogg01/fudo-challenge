# frozen_string_literal: true

RSpec.describe "GET /health", type: :request do
  it "responds 200 when PostgreSQL and Redis answer" do
    get "/health"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to eq("application/json")
    expect(json_body).to eq("status" => "ok", "checks" => { "database" => "ok", "redis" => "ok" })
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
end
