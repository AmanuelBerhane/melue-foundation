# frozen_string_literal: true

module Api
  module V1
    module Parent
      # Guardian portal (SCR-PAR-001…004). Every endpoint is scoped to the
      # signed-in guardian's own children; InternalStudentNote is never exposed.
      class BaseController < Api::V1::BaseController
        MAX_PAGE_SIZE = 100
        DEFAULT_PAGE_SIZE = 20

        before_action :authenticate_user!
        before_action :require_guardian!

        private

        def current_guardian
          @current_guardian ||= Guardian.find_by(user_id: current_user.id) if current_user
        end

        def require_guardian!
          return if performed?
          return if current_guardian && current_user.has_role?(Role::Names::PARENT)

          render_error("Forbidden: Parent access required", :forbidden)
        end

        # 404 rather than 403 for children that are not the guardian's, so
        # student IDs cannot be probed for existence.
        def guardian_student!
          @student = current_guardian.students.kept.find_by(id: params[:student_id] || params[:id])
          render_not_found("Student not found") unless @student
        end

        def page_limit
          limit = params[:limit].to_i
          limit.positive? ? [ limit, MAX_PAGE_SIZE ].min : DEFAULT_PAGE_SIZE
        end

        def page_offset
          [ params[:offset].to_i, 0 ].max
        end

        def paginated(scope)
          [ scope.limit(page_limit).offset(page_offset), { total: scope.count, limit: page_limit, offset: page_offset } ]
        end
      end
    end
  end
end
