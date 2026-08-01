# frozen_string_literal: true

# Helper for generating a valid JWT Authorization header in request specs.
module AuthenticatedHeaders
  def authenticated_headers(user)
    # POST to Rodauth's login endpoint to get a real JWT
    post "/api/v1/auth/login",
         params: { email: user.email, password: "Password123!" },
         as: :json

    token = response.headers["Authorization"]
    { "Authorization" => token, "Content-Type" => "application/json" }
  end
end

RSpec.configure do |config|
  config.include AuthenticatedHeaders, type: :request
end
