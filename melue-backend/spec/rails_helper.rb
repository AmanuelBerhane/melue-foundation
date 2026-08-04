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
    "dummy_token_for_testing"
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
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
