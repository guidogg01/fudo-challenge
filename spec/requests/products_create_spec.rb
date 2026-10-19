# frozen_string_literal: true

RSpec.describe "POST /products", type: :request do
  let(:user) { User.create(username: "ana", password_digest: "not-a-real-digest") }
  let(:valid_body) { { name: "Mesa de roble", description: "Para 4", price_cents: 150_000, quantity: 3 } }

  def authorization_for(user)
    token = SecureRandom.hex(16)
    AuthToken.create(user_id: user.id, token_digest: AuthToken.digest(token), expires_at: Time.now + 60)
    "Bearer #{token}"
  end

  def create_product(body, as: user, headers: {})
    post "/products", JSON.generate(body),
         { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => authorization_for(as) }.merge(headers)
  end

  def detail_for(field)
    json_body.dig("error", "details").find { |detail| detail["field"] == field }
  end

  describe "an accepted request" do
    it "responds 202 with the pending request and its URL in Location" do
      create_product(valid_body)

      expect(last_response.status).to eq(202)
      request_id = json_body.dig("data", "id")
      expect(last_response.headers["location"]).to eq("/product_requests/#{request_id}")
      expect(json_body["data"]).to include(
        "status" => "pending", "product_id" => nil, "product_url" => nil, "error" => nil, "processed_at" => nil
      )
    end

    it "does not create the product yet" do
      create_product(valid_body)

      expect(Product.count).to eq(0)
    end

    it "schedules the job 5 seconds later, with the request id" do
      requested_at = Time.now.to_f
      create_product(valid_body, headers: { "HTTP_X_REQUEST_ID" => "req-1" })

      job = CreateProductJob.jobs.last
      expect(job["args"]).to eq([json_body.dig("data", "id"), "req-1"])
      expect(job["at"]).to be_within(1).of(requested_at + 5)
    end

    it "stores the normalized input as the payload" do
      create_product(valid_body.merge(name: "  Mesa   de\troble "))

      expect(ProductRequest.first.payload["name"]).to eq("Mesa de roble")
    end

    it "is saved for the authenticated user, ignoring a user_id in the body" do
      other = User.create(username: "beto", password_digest: "x")
      create_product(valid_body.merge(user_id: other.id))

      expect(ProductRequest.first.user_id).to eq(user.id)
    end
  end

  describe "validation" do
    {
      "a missing name" => [{ name: nil }, "name", "required"],
      "a name that is not a string" => [{ name: 5 }, "name", "invalid_type"],
      "a name with only spaces" => [{ name: "   " }, "name", "blank"],
      "a name longer than 100 characters" => [{ name: "a" * 101 }, "name", "too_long"],
      "a description that is not a string" => [{ description: 5 }, "description", "invalid_type"],
      "a description longer than 500 characters" => [{ description: "a" * 501 }, "description", "too_long"],
      "a missing price" => [{ price_cents: nil }, "price_cents", "required"],
      "a price with decimals" => [{ price_cents: 10.5 }, "price_cents", "invalid_type"],
      "a price as a string" => [{ price_cents: "100" }, "price_cents", "invalid_type"],
      "a negative price" => [{ price_cents: -1 }, "price_cents", "negative"],
      "a price beyond bigint" => [{ price_cents: 2**63 }, "price_cents", "out_of_range"],
      "a missing quantity" => [{ quantity: nil }, "quantity", "required"],
      "a quantity with decimals" => [{ quantity: 1.0 }, "quantity", "invalid_type"],
      "a negative quantity" => [{ quantity: -1 }, "quantity", "negative"],
      "a quantity beyond integer" => [{ quantity: 2**31 }, "quantity", "out_of_range"]
    }.each do |label, (overrides, field, issue)|
      it "responds 422 for #{label}" do
        create_product(valid_body.merge(overrides))

        expect(last_response.status).to eq(422)
        expect(detail_for(field)).to include("issue" => issue, "message" => a_kind_of(String))
      end
    end

    it "reports every invalid field at once" do
      create_product({})

      expect(json_body.dig("error", "details").map { |detail| detail["field"] }).to eq(
        %w[name price_cents quantity]
      )
    end

    it "accepts a null description" do
      create_product(valid_body.merge(description: nil))

      expect(last_response.status).to eq(202)
    end

    it "does not register anything when the input is invalid" do
      create_product(valid_body.merge(price_cents: -1))

      expect(ProductRequest.count).to eq(0)
      expect(CreateProductJob.jobs).to be_empty
    end
  end

  describe "names already taken" do
    it "responds 409 when the user already has a product with that name, ignoring case" do
      Product.create(user_id: user.id, name: "Mesa de roble", price_cents: 1, quantity: 1)

      create_product(valid_body.merge(name: "MESA DE ROBLE"))

      expect(last_response.status).to eq(409)
      expect(json_body["error"]).to include("code" => "name_already_taken")
      expect(ProductRequest.count).to eq(0)
    end

    it "accepts a name that only another user has" do
      other = User.create(username: "beto", password_digest: "x")
      Product.create(user_id: other.id, name: "Mesa de roble", price_cents: 1, quantity: 1)

      create_product(valid_body)

      expect(last_response.status).to eq(202)
    end
  end

  it "creates the product once the job runs, and the request then points to it" do
    create_product(valid_body.merge(name: " Mesa  de roble "))
    CreateProductJob.drain
    get last_response.headers["location"], {}, "HTTP_AUTHORIZATION" => authorization_for(user)

    product = Product.first(user_id: user.id)
    expect(product.values).to include(name: "Mesa de roble", description: "Para 4", price_cents: 150_000, quantity: 3)
    expect(json_body["data"]).to include("status" => "completed", "product_url" => "/products/#{product.id}")
  end

  it "responds 500 and keeps nothing when the job cannot be enqueued" do
    allow(CreateProductJob).to receive(:perform_in).and_raise(RedisClient::CannotConnectError)

    create_product(valid_body)

    expect(last_response.status).to eq(500)
    expect(ProductRequest.count).to eq(0)
  end

  it "responds 401 without a token" do
    post "/products", JSON.generate(valid_body), "CONTENT_TYPE" => "application/json"

    expect(last_response.status).to eq(401)
  end
end
