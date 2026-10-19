# frozen_string_literal: true

RSpec.describe "Product queries", type: :request do
  let(:user) { User.create(username: "ana", password_digest: "x") }
  let(:other_user) { User.create(username: "beto", password_digest: "x") }

  def authorization_for(user)
    token = SecureRandom.hex(16)
    AuthToken.create(user_id: user.id, token_digest: AuthToken.digest(token), expires_at: Time.now + 60)
    "Bearer #{token}"
  end

  def create_products(count, owner: user)
    Array.new(count) do |i|
      Product.create(user_id: owner.id, name: "Producto #{i + 1}", price_cents: 100 * (i + 1), quantity: i)
    end
  end

  def get_as(user, path, params = {})
    get path, params, "HTTP_AUTHORIZATION" => authorization_for(user)
  end

  describe "GET /products" do
    it "lists only the user's products, ordered by id, with every field" do
      mine = create_products(2)
      create_products(1, owner: other_user)

      get_as(user, "/products")

      expect(last_response.status).to eq(200)
      expect(json_body["data"].map { |product| product["id"] }).to eq(mine.map(&:id))
      expect(json_body.dig("meta", "total")).to eq(2)
      expect(json_body["data"].first.keys).to eq(
        %w[id name description price_cents quantity created_at updated_at]
      )
    end

    it "uses page 1 and 20 per page by default" do
      create_products(21)

      get_as(user, "/products")

      expect(json_body["data"].size).to eq(20)
      expect(json_body["meta"]).to eq("page" => 1, "per_page" => 20, "total" => 21, "total_pages" => 2)
    end

    it "returns the requested page" do
      products = create_products(5)

      get_as(user, "/products", page: "2", per_page: "2")

      expect(json_body["data"].map { |product| product["id"] }).to eq(products[2..3].map(&:id))
      expect(json_body["meta"]).to eq("page" => 2, "per_page" => 2, "total" => 5, "total_pages" => 3)
    end

    it "returns an empty page beyond the last one, even for a huge page number" do
      create_products(1)

      get_as(user, "/products", page: "99999999999999999999999")

      expect(last_response.status).to eq(200)
      expect(json_body["data"]).to eq([])
    end

    it "returns an empty list for a user without products" do
      get_as(user, "/products")

      expect(json_body).to eq(
        "data" => [], "meta" => { "page" => 1, "per_page" => 20, "total" => 0, "total_pages" => 0 }
      )
    end

    it "accepts a page number with a leading zero" do
      get_as(user, "/products", page: "08")

      expect(last_response.status).to eq(200)
    end

    {
      "a page that is not a number" => [{ page: "abc" }, "page", "invalid_type"],
      "a page with decimals" => [{ page: "1.5" }, "page", "invalid_type"],
      "an empty page" => [{ page: "" }, "page", "invalid_type"],
      "a page as an array" => [{ page: ["1"] }, "page", "invalid_type"],
      "page 0" => [{ page: "0" }, "page", "out_of_range"],
      "a negative per_page" => [{ per_page: "-1" }, "per_page", "out_of_range"],
      "per_page 0" => [{ per_page: "0" }, "per_page", "out_of_range"],
      "per_page over 100" => [{ per_page: "101" }, "per_page", "out_of_range"]
    }.each do |label, (params, field, issue)|
      it "responds 422 for #{label}" do
        get_as(user, "/products", params)

        expect(last_response.status).to eq(422)
        expect(json_body.dig("error", "details")).to contain_exactly(
          include("field" => field, "issue" => issue, "message" => a_kind_of(String))
        )
      end
    end

    %w[page=% page[]=1&page[x]=2].each do |query_string|
      it "responds 400 invalid_query for the malformed query string #{query_string}" do
        get "/products", {}, "QUERY_STRING" => query_string, "HTTP_AUTHORIZATION" => authorization_for(user)

        expect(last_response.status).to eq(400)
        expect(json_body.dig("error", "code")).to eq("invalid_query")
      end
    end

    it "responds 401 without a token" do
      get "/products"

      expect(last_response.status).to eq(401)
    end
  end

  describe "GET /products/:id" do
    it "shows one of the user's products" do
      product = Product.create(user_id: user.id, name: "Mesa", description: "Roble", price_cents: 150_000,
                               quantity: 3)

      get_as(user, "/products/#{product.id}")

      expect(last_response.status).to eq(200)
      expect(json_body["data"]).to include(
        "id" => product.id, "name" => "Mesa", "description" => "Roble", "price_cents" => 150_000, "quantity" => 3
      )
    end

    it "responds 404 for a product of another user, as if it did not exist" do
      product = create_products(1, owner: other_user).first

      get_as(user, "/products/#{product.id}")

      expect(last_response.status).to eq(404)
      expect(json_body.dig("error", "code")).to eq("not_found")
    end

    it "responds 404 for an id that does not exist" do
      get_as(user, "/products/999999")

      expect(last_response.status).to eq(404)
    end

    %w[abc 1.5 0 01 99999999999999999999].each do |id|
      it "responds 404 for the id #{id}, without querying the database" do
        allow(Product).to receive(:first).and_call_original

        get_as(user, "/products/#{id}")

        expect(last_response.status).to eq(404)
        expect(Product).not_to have_received(:first)
      end
    end

    it "responds 401 without a token" do
      get "/products/1"

      expect(last_response.status).to eq(401)
    end
  end
end
