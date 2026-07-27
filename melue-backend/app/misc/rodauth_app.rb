class RodauthApp < Rodauth::Rails::App
  # primary configuration
  configure RodauthMain

  # secondary configuration
  # configure RodauthAdmin, :admin

  route do |r|
    r.rodauth # route rodauth requests

    # ==> Secondary configurations
    # r.rodauth(:admin) # route admin rodauth requests
  end
end
