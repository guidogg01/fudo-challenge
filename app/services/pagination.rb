# frozen_string_literal: true

# Valores inválidos dan 422 en vez de corregirse en silencio (decisión 23).
module Pagination
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  MESSAGES = {
    "page" => {
      "invalid_type" => "La página debe ser un número entero.",
      "out_of_range" => "La página debe ser mayor o igual a 1."
    },
    "per_page" => {
      "invalid_type" => "La cantidad por página debe ser un número entero.",
      "out_of_range" => "La cantidad por página debe estar entre 1 y #{MAX_PER_PAGE}."
    }
  }.freeze

  Params = Data.define(:page, :per_page) do
    def offset = (page - 1) * per_page
  end

  def self.parse(query)
    page = query.fetch("page", "1")
    per_page = query.fetch("per_page", DEFAULT_PER_PAGE.to_s)
    issues = { "page" => issue_for(page, max: nil), "per_page" => issue_for(per_page, max: MAX_PER_PAGE) }.compact
    raise ApiError::ValidationFailed, details(issues) if issues.any?

    Params.new(page: Integer(page, 10), per_page: Integer(per_page, 10))
  end

  def self.meta(params, total)
    total_pages = (total + params.per_page - 1) / params.per_page
    { page: params.page, per_page: params.per_page, total: total, total_pages: total_pages }
  end

  # "?page[]=1" llega como Array, y con base 10 explícita "08" no se lee como octal.
  def self.issue_for(value, max:)
    return "invalid_type" unless value.is_a?(String) && value.match?(/\A-?\d+\z/)

    number = Integer(value, 10)
    "out_of_range" if number < 1 || (max && number > max)
  end

  def self.details(issues)
    issues.map { |field, issue| { field: field, issue: issue, message: MESSAGES.fetch(field).fetch(issue) } }
  end

  private_class_method :issue_for, :details
end
