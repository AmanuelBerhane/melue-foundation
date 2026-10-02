# frozen_string_literal: true

module Api
  module V1
    module Sysadmin
      class AuditLogsController < Api::V1::BaseController
        before_action :authenticate_user!

        # GET /api/v1/sysadmin/audit-logs
        def index
          render json: []
        end
      end
    end
  end
end
