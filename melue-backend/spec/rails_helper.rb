# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'


require 'rspec/rails'
require 'factory_bot_rails'
require 'shoulda/matchers'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join('spec/fixtures') ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Authentication helper for request specs
module AuthenticationHelpers
  def jwt_token(user)
    # Generate a real JWT token for the user
    payload = {
      account_id: user.id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end

  def authenticated_headers(user)
    { 'Authorization': "Bearer #{jwt_token(user)}" }
  end

  def json
    JSON.parse(response.body)
  end

  def auth_headers(user)
    authenticated_headers(user)
  end

  # Helper to create a user with the right role
  def create_admin_user
    create(:user, role: :institutional_admin, status: :verified)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
