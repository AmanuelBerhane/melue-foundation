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

    if current_user.closed?
      render json: { error: "Your account has been deactivated." }, status: :forbidden
    end
  end

  def authorize!(resource, action)
    authenticate_user! unless current_user

    unless current_user&.has_permission?(resource, action)
      render json: { error: "You do not have permission to #{action} #{resource}." }, status: :forbidden
    end
  end
end
