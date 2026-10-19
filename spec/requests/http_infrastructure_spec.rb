# frozen_string_literal: true

require "stringio"
require "zlib"

# Rutas inventadas para el test, que pasan por el pipeline de middlewares real.
RSpec.describe "HTTP infrastructure", type: :request do
  let(:log_output) { StringIO.new }
  let(:echo_handler) do
    ->(request) { JsonResponse.build(200, { path_params: request.path_params, json_body: request.json_body }) }
  end
  let(:routes) do
    [
      Route.new("GET", "/things/:id", echo_handler, public: true),
      Route.new("POST", "/things", echo_handler, public: true, json_body: true),
      Route.new("GET", "/things", echo_handler, public: true),
      Route.new("GET", "/private", echo_handler, public: false),
      Route.new("GET", "/boom", ->(_request) { raise "secret detail" }, public: true)
    ]
  end

  def app
    @app ||= Rack::Lint.new(Application.build(routes, logger: Logger.new(log_output, formatter: JSON_LOG_FORMATTER)))
  end

  def log_lines
    log_output.string.lines.map { |line| JSON.parse(line) }
  end

  def post_json(path, body, content_type: "application/json")
    post path, body, "CONTENT_TYPE" => content_type
  end

  describe "routing" do
    it "passes the path parameters to the handler" do
      get "/things/42"

      expect(last_response.status).to eq(200)
      expect(json_body["path_params"]).to eq("id" => "42")
    end

    it "responds 404 with the error format when no route has the path" do
      get "/nowhere"

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to eq("application/json")
      expect(json_body).to eq(
        "error" => { "code" => "not_found", "message" => "No se encontró el recurso.", "details" => [] }
      )
    end

    it "responds 405 with an Allow header when the path exists with other methods" do
      delete "/things"

      expect(last_response.status).to eq(405)
      expect(last_response.headers["allow"]).to eq("POST, GET")
      expect(json_body.dig("error", "code")).to eq("method_not_allowed")
    end

    it "responds 401 on a private route without a token" do
      get "/private"

      expect(last_response.status).to eq(401)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end
  end

  describe "JSON bodies" do
    it "hands the parsed object to the handler" do
      post_json "/things", '{"name":"Mesa"}', content_type: "application/json; charset=utf-8"

      expect(last_response.status).to eq(200)
      expect(json_body["json_body"]).to eq("name" => "Mesa")
    end

    it "responds 415 when the Content-Type is not application/json" do
      post_json "/things", "name=Mesa", content_type: "application/x-www-form-urlencoded"

      expect(last_response.status).to eq(415)
      expect(json_body.dig("error", "code")).to eq("unsupported_media_type")
    end

    it "responds 400 when the body is not valid JSON" do
      post_json "/things", '{"name":'

      expect(last_response.status).to eq(400)
      expect(json_body.dig("error", "code")).to eq("invalid_json")
    end

    it "responds 400 when the body is valid JSON but not an object" do
      post_json "/things", "[1, 2]"

      expect(last_response.status).to eq(400)
      expect(json_body.dig("error", "message")).to eq("El cuerpo del request debe ser un objeto JSON.")
    end

    it "responds 400 when the body is not valid UTF-8" do
      post_json "/things", "{\"name\":\"\xFF\"}".b

      expect(last_response.status).to eq(400)
      expect(json_body.dig("error", "code")).to eq("invalid_json")
    end

    it "responds 400 when a string contains a NUL character" do
      post_json "/things", '{"name":"Me\u0000sa"}'

      expect(last_response.status).to eq(400)
      expect(json_body.dig("error", "message")).to eq("El cuerpo del request no puede contener el carácter nulo.")
    end

    it "responds 400 when the JSON is nested too deeply" do
      post_json "/things", "{\"a\":#{'[' * 1000}#{']' * 1000}}"

      expect(last_response.status).to eq(400)
      expect(json_body.dig("error", "code")).to eq("invalid_json")
    end
  end

  describe "unexpected errors" do
    it "responds 500 without revealing the cause" do
      get "/boom"

      expect(last_response.status).to eq(500)
      expect(json_body.dig("error", "code")).to eq("internal_error")
      expect(last_response.body).not_to include("secret detail")
    end

    it "logs the cause with the request id" do
      get "/boom", {}, "HTTP_X_REQUEST_ID" => "req-123"

      error_line = log_lines.find { |line| line["event"] == "unhandled_error" }
      expect(error_line).to include("level" => "error", "request_id" => "req-123", "error_message" => "secret detail")
    end
  end

  describe "X-Request-Id" do
    it "generates a UUID when the client sends none" do
      get "/things/1"

      expect(last_response.headers["x-request-id"]).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it "keeps the id the client sends" do
      get "/things/1", {}, "HTTP_X_REQUEST_ID" => "client-id-1"

      expect(last_response.headers["x-request-id"]).to eq("client-id-1")
    end

    it "replaces an id with characters that do not belong in logs" do
      get "/things/1", {}, "HTTP_X_REQUEST_ID" => "bad id\ninjected"

      expect(last_response.headers["x-request-id"]).not_to include("injected")
    end

    it "is also returned on errors" do
      get "/nowhere", {}, "HTTP_X_REQUEST_ID" => "client-id-2"

      expect(last_response.headers["x-request-id"]).to eq("client-id-2")
    end
  end

  describe "request log" do
    it "writes one JSON line per request with method, path, status, duration and request id" do
      get "/nowhere", {}, "HTTP_X_REQUEST_ID" => "client-id-3"

      expect(log_lines.size).to eq(1)
      expect(log_lines.first).to include(
        "level" => "info", "event" => "request", "method" => "GET", "path" => "/nowhere",
        "status" => 404, "request_id" => "client-id-3", "user_id" => nil
      )
      expect(log_lines.first["duration_ms"]).to be_a(Numeric)
    end
  end

  describe "gzip" do
    it "compresses the response when the client accepts gzip" do
      get "/things/7", {}, "HTTP_ACCEPT_ENCODING" => "gzip"

      expect(last_response.headers["content-encoding"]).to eq("gzip")
      expect(last_response.headers["vary"]).to include("Accept-Encoding")
      expect(JSON.parse(Zlib.gunzip(last_response.body))).to include("path_params" => { "id" => "7" })
    end

    it "compresses error responses too" do
      get "/nowhere", {}, "HTTP_ACCEPT_ENCODING" => "gzip"

      expect(last_response.headers["content-encoding"]).to eq("gzip")
      expect(JSON.parse(Zlib.gunzip(last_response.body)).dig("error", "code")).to eq("not_found")
    end

    it "does not compress when the client does not ask for it" do
      get "/things/7"

      expect(last_response.headers).not_to have_key("content-encoding")
      expect(json_body["path_params"]).to eq("id" => "7")
    end
  end
end
