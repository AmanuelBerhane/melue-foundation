module Api
  module V1
    class GoalsController < Api::V1::BaseController
      before_action :authenticate_user!

      def search
        scope = Goal.active.includes(:goal_domain)

        if params[:goal_domain_id].present?
          scope = scope.where(goal_domain_id: params[:goal_domain_id])
        end

        if params[:therapy_group].present?
          scope = scope.for_therapy_group(params[:therapy_group])
        end

        if params[:q].present?
          scope = scope.where(
            "LOWER(goals.name) LIKE ? OR LOWER(goals.description) LIKE ?",
            "%#{params[:q].downcase}%",
            "%#{params[:q].downcase}%"
          )
        end

        page = [ params[:page].to_i, 1 ].max
        per_page = 50

        paginated_scope = scope.offset((page - 1) * per_page).limit(per_page)
        total_count = scope.count

        goals_payload = paginated_scope.map do |goal|
          {
            id: goal.id,
            name: goal.name,
            description: goal.description,
            goal_domain: {
              id: goal.goal_domain.id,
              name: goal.goal_domain.name
            },
            goal_type: goal.goal_type,
            suggested_age_range: goal.suggested_age_range,
            applicable_therapy_groups: goal.applicable_therapy_groups,
            is_active: goal.is_active
          }
        end

        render json: {
          goals: goals_payload,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }, status: :ok
      end
    end
  end
end
