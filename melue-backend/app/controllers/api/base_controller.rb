class Api::BaseController < ApplicationController
  private

  def rodauth
    request.env["rodauth"]
  end

  def current_user
    rodauth.rails_account
  end

  def authenticate_user!
    rodauth.require_account
  end

  def set_current_user
    Current.user = current_user if respond_to?(:current_user)
  end
end
