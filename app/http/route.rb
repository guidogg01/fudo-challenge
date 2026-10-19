# frozen_string_literal: true

# One line of the routing table: an HTTP method, a path pattern such as
# "/products/:id", and the handler that answers it.
#
# `public:` has no default on purpose: adding a route forces the decision of
# whether it needs authentication (see DECISIONS.md, decision 9).
class Route
  attr_reader :verb, :handler

  def initialize(verb, pattern, handler, public:, json_body: false)
    @verb = verb
    @handler = handler
    @public = public
    @json_body = json_body
    @regexp = compile(pattern)
  end

  def public? = @public

  # Whether the router must parse a JSON object from the body before calling the handler.
  def json_body? = @json_body

  # The path parameters when the path matches ({ id: "42" } for "/products/42"),
  # nil when it does not.
  def match(path)
    match_data = @regexp.match(path)
    match_data&.named_captures&.transform_keys(&:to_sym)
  end

  private

  # "/products/:id" becomes /\A\/products\/(?<id>[^\/]+)\z/: each ":name"
  # segment captures one path segment, everything else must match literally.
  def compile(pattern)
    segments = pattern.split("/").map do |segment|
      segment.start_with?(":") ? "(?<#{segment.delete_prefix(':')}>[^/]+)" : Regexp.escape(segment)
    end
    Regexp.new("\\A#{segments.join('/')}\\z")
  end
end
