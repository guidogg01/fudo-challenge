# frozen_string_literal: true

module JsonResponse
  # Content-Length se calcula acá porque Rack::Head vacía el body de un HEAD
  # antes de que Puma lo pueda medir, y tiene que coincidir con el del GET (RFC 9110, 8.6).
  def self.build(status, body, headers = {})
    json = JSON.generate(body)
    [status, { "content-type" => "application/json", "content-length" => json.bytesize.to_s }.merge(headers), [json]]
  end
end
