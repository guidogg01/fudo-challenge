# frozen_string_literal: true

module ProductInput
  NAME_MAX_LENGTH = 100
  DESCRIPTION_MAX_LENGTH = 500
  # Los límites de las columnas bigint e integer: un número más grande fallaría
  # en PostgreSQL con un 500 en vez de un 422 claro.
  PRICE_CENTS_MAX = (2**63) - 1
  QUANTITY_MAX = (2**31) - 1

  MESSAGES = {
    "name" => {
      "required" => "El nombre es obligatorio.",
      "invalid_type" => "El nombre debe ser un texto.",
      "blank" => "El nombre no puede estar vacío.",
      "too_long" => "El nombre no puede superar los #{NAME_MAX_LENGTH} caracteres."
    },
    "description" => {
      "invalid_type" => "La descripción debe ser un texto.",
      "too_long" => "La descripción no puede superar los #{DESCRIPTION_MAX_LENGTH} caracteres."
    },
    "price_cents" => {
      "required" => "El precio es obligatorio.",
      "invalid_type" => "El precio debe ser un número entero de centavos.",
      "negative" => "El precio no puede ser negativo.",
      "out_of_range" => "El precio es demasiado grande."
    },
    "quantity" => {
      "required" => "La cantidad es obligatoria.",
      "invalid_type" => "La cantidad debe ser un número entero.",
      "negative" => "La cantidad no puede ser negativa.",
      "out_of_range" => "La cantidad es demasiado grande."
    }
  }.freeze

  def self.validate!(body)
    attributes = normalize(body)
    issues = issues_in(attributes)
    raise ApiError::ValidationFailed, details(issues) if issues.any?

    attributes
  end

  def self.normalize(body)
    {
      "name" => normalize_name(body["name"]),
      "description" => body["description"],
      "price_cents" => body["price_cents"],
      "quantity" => body["quantity"]
    }
  end

  def self.issues_in(attributes)
    {
      "name" => name_issue(attributes["name"]),
      "description" => description_issue(attributes["description"]),
      "price_cents" => integer_issue(attributes["price_cents"], PRICE_CENTS_MAX),
      "quantity" => integer_issue(attributes["quantity"], QUANTITY_MAX)
    }.compact
  end

  # "  Mesa   de roble " y "Mesa de roble" son el mismo nombre.
  def self.normalize_name(name)
    name.is_a?(String) ? name.gsub(/[[:space:]]+/, " ").strip : name
  end

  def self.name_issue(name)
    if name.nil? then "required"
    elsif !name.is_a?(String) then "invalid_type"
    elsif name.empty? then "blank"
    elsif name.length > NAME_MAX_LENGTH then "too_long"
    end
  end

  def self.description_issue(description)
    if description.nil? then nil
    elsif !description.is_a?(String) then "invalid_type"
    elsif description.length > DESCRIPTION_MAX_LENGTH then "too_long"
    end
  end

  # 10.5, 10.0 y "10" se rechazan, nunca se redondean ni se convierten (decisión 18).
  def self.integer_issue(value, max)
    if value.nil? then "required"
    elsif !value.is_a?(Integer) then "invalid_type"
    elsif value.negative? then "negative"
    elsif value > max then "out_of_range"
    end
  end

  def self.details(issues)
    issues.map { |field, issue| { field: field, issue: issue, message: MESSAGES.fetch(field).fetch(issue) } }
  end

  private_class_method :normalize, :issues_in, :normalize_name, :name_issue, :description_issue,
                       :integer_issue, :details
end
