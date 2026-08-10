class Rack::Attack
  # Throttle login attempts to 20 requests per second per IP address.
  # The actual Rodauth login route is under the /api/v1/auth prefix.
  throttle("logins/ip", limit: 20, period: 1.second) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      req.ip
    end
  end

  # Rate-limit per-account brute-force attempts: allow 5 failed login attempts
  # per account within a 15-minute window, then block further attempts (NFR-019).
  # The account is identified by the submitted login (email) parameter.
  throttle("logins/account", limit: 5, period: 15.minutes) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      email = req.params["email"].to_s.downcase.strip
      email.presence
    end
  end

  # Custom response for rate limiting.
  self.throttled_responder = lambda do |env|
    [ 429, { "Content-Type" => "application/json" },
    [ { error: "Too many login attempts. Please wait before trying again." }.to_json ] ]
  end
end
