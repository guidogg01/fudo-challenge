# frozen_string_literal: true

# Builds a Rack response with a JSON body, so every handler and the error
# handler produce the same content type.
module JsonResponse
  def self.build(status, body, headers = {})
    [status, { "content-type" => "application/json" }.merge(headers), [JSON.generate(body)]]
  end
end
