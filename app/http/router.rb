# frozen_string_literal: true

# Escrito a mano a propósito: el enunciado prohíbe los frameworks web (decisión 1).
class Router
  def initialize(routes)
    @routes = routes
  end

  def call(env)
    request = ApiRequest.new(env)
    route, path_params = find_route(request)

    request.path_params = path_params
    authenticate(request) unless route.public?
    request.json_body = JsonBody.parse(request) if route.json_body?

    route.handler.call(request)
  end

  private

  def find_route(request)
    matches = @routes.filter_map do |route|
      path_params = route.match(request.path_info)
      [route, path_params] if path_params
    end
    raise ApiError::NotFound if matches.empty?

    match = matches.find { |route, _| route.verb == routed_verb(request) }
    raise ApiError::MethodNotAllowed, matches.map { |route, _| route.verb }.uniq unless match

    match
  end

  # HEAD es un GET sin body (Rack::Head lo vacía), así que usa las mismas rutas.
  def routed_verb(request)
    request.head? ? "GET" : request.request_method
  end

  # El usuario sale siempre del token, nunca del body ni de la URL.
  def authenticate(request)
    auth_token = TokenAuthentication.call(request.get_header("HTTP_AUTHORIZATION"))
    request.auth_token = auth_token
    request.current_user = auth_token.user
  end
end
