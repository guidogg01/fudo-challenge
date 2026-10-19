# frozen_string_literal: true

module JsonResponse
  def self.build(status, body, headers = {})
    [status, { "content-type" => "application/json" }.merge(headers), [JSON.generate(body)]]
  end
end
