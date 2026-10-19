# frozen_string_literal: true

RSpec.describe "GET /health", type: :request do
  it "responds 200 with status ok as JSON" do
    get "/health"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to eq("application/json")
    expect(json_body).to eq("status" => "ok")
  end
end
