class RodauthApp < Rodauth::Rails::App
  # primary configuration
  configure RodauthMain

  # secondary configuration
  # configure RodauthAdmin, :admin

  route do |r|
    # Strip empty, undefined, null, or public auth Authorization headers so they do not cause 400 Bad Request
    auth = r.env["HTTP_AUTHORIZATION"] || r.env["HTTP_X_AUTHORIZATION"]
    if auth.present?
      token = auth.to_s.sub(/\ABearer:?\s+/i, "").strip
      if token.blank? || token == "undefined" || token == "null"
        r.env.delete("HTTP_AUTHORIZATION")
        r.env.delete("HTTP_X_AUTHORIZATION")
      end
    end

    if r.request_method == "POST" && r.path.to_s =~ %r{/auth/(login|create-account|reset-password)\b}
      r.env.delete("HTTP_AUTHORIZATION")
      r.env.delete("HTTP_X_AUTHORIZATION")
    end

    if r.request_method == "POST" && r.path.to_s =~ %r{/auth/logout\b}
      catch(:halt) do
        r.rodauth
      rescue => _e
        # ignore error on expired token
      end
      r.response.status = 200
      r.response["Content-Type"] = "application/json"
      r.halt [ 200, { "Content-Type" => "application/json" }, [ '{"success":true,"message":"Logged out"}' ] ]
    end

    r.rodauth # route rodauth requests
  end
end
