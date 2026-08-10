module Api
  module V1
    module Admin
      class BaseController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :set_current_user
        before_action :require_institutional_admin
      end
    end
  end
end
