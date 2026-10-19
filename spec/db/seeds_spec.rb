# frozen_string_literal: true

RSpec.describe "db/seeds.rb" do
  def run_seeds
    load File.expand_path("../../db/seeds.rb", __dir__)
  end

  it "creates the demo user with a bcrypt digest of its password" do
    expect { run_seeds }.to output("Created user demo\n").to_stdout

    user = User.first(username: "demo")
    expect(BCrypt::Password.new(user.password_digest)).to eq("demo1234")
  end

  it "does not create the demo user twice" do
    expect { 2.times { run_seeds } }.to output(/already exists/).to_stdout

    expect(User.where(username: "demo").count).to eq(1)
  end
end
