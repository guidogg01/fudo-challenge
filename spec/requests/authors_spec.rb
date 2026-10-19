# frozen_string_literal: true

require "time"
require "zlib"

RSpec.describe "GET /AUTHORS", type: :request do
  it "serves the author's name as plain text, without a token" do
    get "/AUTHORS"

    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to eq("text/plain; charset=utf-8")
    expect(last_response.body).to eq("Guido Greco\n")
  end

  it "lets clients and proxies cache it for 24 hours" do
    get "/AUTHORS"

    expect(last_response.headers["cache-control"]).to eq("public, max-age=86400")
    expect(Time.httpdate(last_response.headers["last-modified"])).to be_a(Time)
  end

  it "responds 304 without a body when it has not changed since If-Modified-Since" do
    last_modified = File.mtime(File.join(AuthorsHandler::PUBLIC_DIR, "AUTHORS")).httpdate

    get "/AUTHORS", {}, "HTTP_IF_MODIFIED_SINCE" => last_modified

    expect(last_response.status).to eq(304)
    expect(last_response.body).to be_empty
    expect(last_response.headers["cache-control"]).to eq("public, max-age=86400")
  end

  it "goes through the pipeline: request id and gzip" do
    get "/AUTHORS", {}, "HTTP_ACCEPT_ENCODING" => "gzip"

    expect(last_response.headers["x-request-id"]).not_to be_nil
    expect(last_response.headers["content-encoding"]).to eq("gzip")
    expect(Zlib.gunzip(last_response.body)).to eq("Guido Greco\n")
  end

  it "answers HEAD like GET, without a body" do
    head "/AUTHORS"

    expect(last_response.status).to eq(200)
    expect(last_response.headers["cache-control"]).to eq("public, max-age=86400")
    expect(last_response.body).to be_empty
  end

  it "responds 405 to other methods" do
    post "/AUTHORS"

    expect(last_response.status).to eq(405)
    expect(last_response.headers["allow"]).to eq("GET")
  end
end
