# frozen_string_literal: true

RSpec.describe "GET /product_requests/:id", type: :request do
  let(:user) { User.create(username: "ana", password_digest: "x") }
  let(:payload) { Sequel.pg_jsonb("name" => "Mesa", "description" => nil, "price_cents" => 100, "quantity" => 1) }

  def authorization_for(user)
    token = SecureRandom.hex(16)
    AuthToken.create(user_id: user.id, token_digest: AuthToken.digest(token), expires_at: Time.now + 60)
    "Bearer #{token}"
  end

  def get_request(id, as: user)
    get "/product_requests/#{id}", {}, "HTTP_AUTHORIZATION" => authorization_for(as)
  end

  it "shows a pending request" do
    product_request = ProductRequest.create(user_id: user.id, payload: payload)

    get_request(product_request.id)

    expect(last_response.status).to eq(200)
    expect(json_body["data"]).to include("id" => product_request.id, "status" => "pending", "error" => nil)
  end

  it "shows a completed request with its product" do
    product = Product.create(user_id: user.id, name: "Mesa", price_cents: 100, quantity: 1)
    product_request = ProductRequest.create(
      user_id: user.id, payload: payload, status: "completed", product_id: product.id, processed_at: Time.now
    )

    get_request(product_request.id)

    expect(json_body["data"]).to include(
      "status" => "completed", "product_id" => product.id, "product_url" => "/products/#{product.id}"
    )
    expect(Time.iso8601(json_body.dig("data", "processed_at"))).to be_a(Time)
  end

  it "shows a failed request with the reason" do
    product_request = ProductRequest.create(
      user_id: user.id, payload: payload, status: "failed", error_code: "name_already_taken",
      error_message: "Ya tenés un producto con ese nombre.", processed_at: Time.now
    )

    get_request(product_request.id)

    expect(json_body["data"]).to include(
      "status" => "failed", "product_id" => nil,
      "error" => { "code" => "name_already_taken", "message" => "Ya tenés un producto con ese nombre." }
    )
  end

  it "responds 404 for a request of another user, as if it did not exist" do
    other = User.create(username: "beto", password_digest: "x")
    product_request = ProductRequest.create(user_id: other.id, payload: payload)

    get_request(product_request.id)

    expect(last_response.status).to eq(404)
    expect(json_body.dig("error", "code")).to eq("not_found")
  end

  it "responds 404 for an id that does not exist" do
    get_request(SecureRandom.uuid)

    expect(last_response.status).to eq(404)
  end

  it "responds 404 for an id that is not a UUID, without querying the database" do
    allow(ProductRequest).to receive(:first).and_call_original

    get_request("42")

    expect(last_response.status).to eq(404)
    expect(ProductRequest).not_to have_received(:first)
  end

  it "responds 401 without a token" do
    get "/product_requests/#{SecureRandom.uuid}"

    expect(last_response.status).to eq(401)
  end
end
