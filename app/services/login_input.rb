# frozen_string_literal: true

module LoginInput
  MESSAGES = {
    "username" => {
      "required" => "El usuario es obligatorio.",
      "invalid_type" => "El usuario debe ser un texto.",
      "blank" => "El usuario no puede estar vacío."
    },
    "password" => {
      "required" => "La contraseña es obligatoria.",
      "invalid_type" => "La contraseña debe ser un texto.",
      "blank" => "La contraseña no puede estar vacía."
    }
  }.freeze

  def self.validate!(body)
    attributes = { "username" => body["username"], "password" => body["password"] }
    issues = attributes.transform_values { |value| issue_for(value) }.compact
    raise ApiError::ValidationFailed.from_issues(issues, MESSAGES) if issues.any?

    attributes
  end

  def self.issue_for(value)
    if value.nil? then "required"
    elsif !value.is_a?(String) then "invalid_type"
    elsif value.strip.empty? then "blank"
    end
  end

  private_class_method :issue_for
end
