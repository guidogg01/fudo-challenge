# frozen_string_literal: true

# The request object handlers receive. Rack::Request already reads the
# method, path, headers and body from the env; this adds what the router
# works out for the handler. Values live in the env, so the middlewares
# (for example RequestLogger) can read them too.
class ApiRequest < Rack::Request
  PATH_PARAMS_KEY = "app.path_params"
  JSON_BODY_KEY = "app.json_body"
  CURRENT_USER_KEY = "app.current_user"

  def path_params
    get_header(PATH_PARAMS_KEY) || {}
  end

  def path_params=(params)
    set_header(PATH_PARAMS_KEY, params)
  end

  def json_body
    get_header(JSON_BODY_KEY)
  end

  def json_body=(body)
    set_header(JSON_BODY_KEY, body)
  end

  def current_user
    get_header(CURRENT_USER_KEY)
  end

  def current_user=(user)
    set_header(CURRENT_USER_KEY, user)
  end
end
