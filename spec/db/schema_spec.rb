# frozen_string_literal: true

# The database constraints are the guarantee behind the app's validations
# (decisions 16 and 19), so they are tested directly.
RSpec.describe "Database schema" do
  def create_user(username = "ana")
    User.create(username: username, password_digest: "not-a-real-digest")
  end

  def create_token(user)
    AuthToken.create(user_id: user.id, token_digest: "a" * 64, expires_at: Time.now + 60)
  end

  def product_attributes(user, overrides = {})
    { user_id: user.id, name: "Mesa", description: nil, price_cents: 150_000, quantity: 1 }.merge(overrides)
  end

  def create_request(user, attributes = {})
    ProductRequest.create({ user_id: user.id, payload: Sequel.pg_jsonb("name" => "Mesa") }.merge(attributes))
  end

  describe "users" do
    it "rejects a username that differs only in case" do
      create_user("Ana")

      expect { create_user("ana") }.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end

  describe "auth_tokens" do
    it "rejects a repeated token digest" do
      user = create_user
      create_token(user)

      expect { create_token(user) }.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it "is deleted together with its user" do
      user = create_user
      create_token(user)

      user.destroy

      expect(AuthToken.count).to eq(0)
    end
  end

  describe "products" do
    it "rejects a name the same user already has, ignoring case" do
      user = create_user
      Product.create(product_attributes(user, name: "Mesa"))

      expect { Product.create(product_attributes(user, name: "MESA")) }
        .to raise_error(Sequel::UniqueConstraintViolation)
    end

    it "allows two users to have a product with the same name" do
      Product.create(product_attributes(create_user("ana"), name: "Mesa"))

      expect { Product.create(product_attributes(create_user("beto"), name: "Mesa")) }.not_to raise_error
    end

    {
      "an empty name" => { name: "" },
      "a name longer than 100 characters" => { name: "a" * 101 },
      "a description longer than 500 characters" => { description: "a" * 501 },
      "a negative price" => { price_cents: -1 },
      "a negative quantity" => { quantity: -1 }
    }.each do |label, overrides|
      it "rejects #{label}" do
        expect { Product.create(product_attributes(create_user, overrides)) }
          .to raise_error(Sequel::CheckConstraintViolation)
      end
    end
  end

  describe "product_requests" do
    let(:user) { create_user }

    it "starts as pending with a generated UUID" do
      request = create_request(user).refresh

      expect(request.status).to eq("pending")
      expect(request.id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it "rejects an unknown status" do
      expect { create_request(user, status: "done") }.to raise_error(Sequel::CheckConstraintViolation)
    end

    it "rejects completed without a product" do
      expect { create_request(user, status: "completed") }.to raise_error(Sequel::CheckConstraintViolation)
    end

    it "rejects a product on a request that is not completed" do
      product = Product.create(product_attributes(user))

      expect { create_request(user, product_id: product.id) }.to raise_error(Sequel::CheckConstraintViolation)
    end

    it "accepts completed with a product" do
      product = Product.create(product_attributes(user))

      expect { create_request(user, status: "completed", product_id: product.id) }.not_to raise_error
    end
  end
end
