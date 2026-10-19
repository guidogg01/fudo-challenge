# frozen_string_literal: true

# El enunciado prohíbe los frameworks web (decisión 1); este test lo hace fallar si alguno
# entra como dependencia, incluso de forma indirecta.
RSpec.describe "Dependencies" do
  let(:locked_gems) do
    Bundler::LockfileParser.new(File.read(File.expand_path("../Gemfile.lock", __dir__))).specs.map(&:name)
  end

  it "includes no web framework" do
    expect(locked_gems).not_to include("rails", "railties", "sinatra", "roda", "hanami", "grape", "padrino")
  end
end
