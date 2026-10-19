# frozen_string_literal: true

# `public:` no tiene valor por defecto a propósito: agregar una ruta obliga a decidir
# si necesita autenticación (decisión 9).
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

  def json_body? = @json_body

  def match(path)
    match_data = @regexp.match(path)
    match_data&.named_captures&.transform_keys(&:to_sym)
  end

  private

  # "/products/:id" se convierte en /\A\/products\/(?<id>[^\/]+)\z/
  def compile(pattern)
    segments = pattern.split("/").map do |segment|
      segment.start_with?(":") ? "(?<#{segment.delete_prefix(':')}>[^/]+)" : Regexp.escape(segment)
    end
    Regexp.new("\\A#{segments.join('/')}\\z")
  end
end
