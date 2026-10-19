# frozen_string_literal: true

RSpec.describe "Authentication", type: :request do
  let!(:user) { create_user("Demo", password: "demo1234") }

  def login(body, content_type: "application/json")
    post "/auth/login", JSON.generate(body), "CONTENT_TYPE" => content_type
  end

  def logout(authorization = nil)
    headers = authorization ? { "HTTP_AUTHORIZATION" => authorization } : {}
    post "/auth/logout", nil, headers
  end

  def expect_invalid_credentials
    expect(last_response.status).to eq(401)
    expect(json_body).to eq(
      "error" => { "code" => "invalid_credentials", "message" => "Usuario o contraseña incorrectos.", "details" => [] }
    )
  end

  def expect_unauthorized
    expect(last_response.status).to eq(401)
    expect(json_body).to eq(
      "error" => { "code" => "unauthorized", "message" => "Necesitás un token válido para acceder.", "details" => [] }
    )
  end

  describe "POST /auth/login" do
    it "returns a Bearer token that expires in 24 hours" do
      login({ username: "Demo", password: "demo1234" })

      expect(last_response.status).to eq(200)
      expect(json_body["data"]).to include("token" => a_kind_of(String), "token_type" => "Bearer")
      expect(Time.iso8601(json_body.dig("data", "expires_at"))).to be_within(5).of(Time.now + 86_400)
      expect(last_response.headers["cache-control"]).to eq("no-store")
    end

    it "stores only the SHA-256 of the token" do
      login({ username: "Demo", password: "demo1234" })
      token = json_body.dig("data", "token")

      stored = AuthToken.first(user_id: user.id)
      expect(stored.token_digest).to eq(Digest::SHA256.hexdigest(token))
    end

    it "responds 400 instead of failing when the username has a NUL character" do
      login({ username: "de\u0000mo", password: "demo1234" })

      expect(last_response.status).to eq(400)
    end

    it "finds the user without distinguishing case" do
      login({ username: "DEMO", password: "demo1234" })

      expect(last_response.status).to eq(200)
    end

    it "responds 401 invalid_credentials when the password is wrong" do
      login({ username: "Demo", password: "wrong" })

      expect_invalid_credentials
    end

    it "responds the same 401 when the user does not exist" do
      login({ username: "nobody", password: "demo1234" })

      expect_invalid_credentials
    end

    it "runs bcrypt even when the user does not exist, so both failures take the same time" do
      allow(BCrypt::Password).to receive(:new).and_call_original

      login({ username: "nobody", password: "demo1234" })

      expect(BCrypt::Password).to have_received(:new).with(Login::DUMMY_PASSWORD_DIGEST)
    end

    it "does not issue a token when the login fails" do
      login({ username: "Demo", password: "wrong" })

      expect(AuthToken.count).to eq(0)
    end

    it "responds 422 with one detail per invalid field" do
      login({ username: "  ", password: 1234 })

      expect(last_response.status).to eq(422)
      expect(json_body["error"]).to include(
        "code" => "validation_failed", "message" => "Los datos enviados no son válidos."
      )
      expect(json_body.dig("error", "details")).to eq(
        [
          { "field" => "username", "issue" => "blank", "message" => "El usuario no puede estar vacío." },
          { "field" => "password", "issue" => "invalid_type", "message" => "La contraseña debe ser un texto." }
        ]
      )
    end

    it "responds 422 when fields are missing" do
      login({})

      expect(json_body.dig("error", "details").map { |detail| detail["issue"] }).to eq(%w[required required])
    end

    it "responds 415 without a JSON Content-Type" do
      login({ username: "Demo", password: "demo1234" }, content_type: "text/plain")

      expect(last_response.status).to eq(415)
    end
  end

  describe "private routes" do
    it "accept a valid token" do
      logout("Bearer #{issue_token(user)}")

      expect(last_response.status).to eq(204)
    end

    it "accept the scheme name in any case" do
      logout("bearer #{issue_token(user)}")

      expect(last_response.status).to eq(204)
    end

    it "respond 401 without an Authorization header" do
      logout

      expect_unauthorized
    end

    it "respond 401 with a malformed header" do
      logout("Token #{issue_token(user)}")

      expect_unauthorized
    end

    it "respond 401 with an unknown token" do
      logout("Bearer not-a-real-token")

      expect_unauthorized
    end

    it "respond 401 with an expired token" do
      logout("Bearer #{issue_token(user, expires_at: Time.now - 1)}")

      expect_unauthorized
    end

    it "respond 401 with a revoked token" do
      logout("Bearer #{issue_token(user, revoked_at: Time.now - 1)}")

      expect_unauthorized
    end
  end

  describe "POST /auth/logout" do
    it "responds 204 without a body" do
      logout("Bearer #{issue_token(user)}")

      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
    end

    it "revokes the token, which then gets 401" do
      token = issue_token(user)

      logout("Bearer #{token}")
      expect(last_response.status).to eq(204)

      logout("Bearer #{token}")
      expect_unauthorized
    end

    it "ignores a body, since logout reads none" do
      post "/auth/logout", "not json", "HTTP_AUTHORIZATION" => authorization_for(user), "CONTENT_TYPE" => "text/plain"

      expect(last_response.status).to eq(204)
    end

    it "leaves the user's other tokens working" do
      other_token = issue_token(user)
      logout("Bearer #{issue_token(user)}")

      logout("Bearer #{other_token}")

      expect(last_response.status).to eq(204)
    end
  end

  describe "request log" do
    def app
      @app ||= Application.build(ROUTES, logger: test_logger)
    end

    it "records the id of the authenticated user" do
      logout("Bearer #{issue_token(user)}")

      expect(JSON.parse(log_output.string.lines.last)).to include("path" => "/auth/logout", "user_id" => user.id)
    end

    it "never records the password or the token" do
      login({ username: "Demo", password: "demo1234" })

      expect(log_output.string).not_to include("demo1234")
      expect(log_output.string).not_to include(json_body.dig("data", "token"))
    end
  end
end
