# frozen_string_literal: true

# Los valores viven en el env para que los middlewares, como RequestLogger, también los lean.
class ApiRequest < Rack::Request
  PATH_PARAMS_KEY = "app.path_params"
  JSON_BODY_KEY = "app.json_body"
  CURRENT_USER_KEY = "app.current_user"
  AUTH_TOKEN_KEY = "app.auth_token"

  def path_params
    get_header(PATH_PARAMS_KEY) || {}
  end

  def path_params=(params)
    set_header(PATH_PARAMS_KEY, params)
  end

  # Rack lanza estas excepciones con un query string mal formado (por ejemplo "?page=%");
  # sin traducirlas terminarían en un 500.
  QUERY_ERRORS = [
    Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError, Rack::QueryParser::QueryLimitError
  ].freeze

  def query_params
    self.GET
  rescue *QUERY_ERRORS
    raise ApiError::InvalidQuery
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

  def auth_token
    get_header(AUTH_TOKEN_KEY)
  end

  def auth_token=(token)
    set_header(AUTH_TOKEN_KEY, token)
  end
end
