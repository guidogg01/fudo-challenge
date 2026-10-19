# frozen_string_literal: true

# Hand-written router (see DECISIONS.md, decision 1). It finds the route for
# the request and prepares what the handler needs: path parameters, the
# authenticated user and the parsed JSON body.
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

  # 404 when no route has this path; 405 when the path exists but not with
  # this method.
  def find_route(request)
    matches = @routes.filter_map do |route|
      path_params = route.match(request.path_info)
      [route, path_params] if path_params
    end
    raise ApiError::NotFound if matches.empty?

    match = matches.find { |route, _| route.verb == request.request_method }
    raise ApiError::MethodNotAllowed, matches.map { |route, _| route.verb }.uniq unless match

    match
  end

  # The user always comes from the token, never from the body or the URL.
  def authenticate(request)
    auth_token = TokenAuthentication.call(request.get_header("HTTP_AUTHORIZATION"))
    request.auth_token = auth_token
    request.current_user = auth_token.user
  end
end
