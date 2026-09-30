# frozen_string_literal: true

module Api
  module V1
    # FR-073: Provides domain filter chips to filter the Goal Bank.
    class GoalDomainsController < Api::V1::BaseController
      before_action :authenticate_user!
      before_action :set_goal_domain, only: [ :show ]

      # GET /api/v1/goal_domains
      #
      # @summary List active goal domains for filter chips
      # @tags Goal Domains
      # @auth [bearer_jwt]
      # @response (200) [Array<Hash{id: String, name: String, description: String, display_order: Integer, is_active: Boolean, goals_count: Integer}>]
      # @response (401) Hash{error: String}
      def index
        domains = GoalDomain.active.order(:display_order)

        # Precompute active goals count per domain
        counts = Goal.kept.active.group(:goal_domain_id).count

        payload = domains.map do |domain|
          {
            id: domain.id,
            name: domain.name,
            description: domain.description,
            display_order: domain.display_order,
            is_active: domain.is_active,
            goals_count: counts[domain.id] || 0
          }
        end

        render json: payload, status: :ok
      end

      # GET /api/v1/goal_domains/:id
      #
      # @summary Get a goal domain
      # @tags Goal Domains
      # @auth [bearer_jwt]
      # @parameter id(path) [!String] The goal domain ID
      # @response (200) Hash{id: String, name: String, description: String, display_order: Integer, is_active: Boolean}
      # @response (404) Hash{error: String}
      def show
        render json: {
          id: @goal_domain.id,
          name: @goal_domain.name,
          description: @goal_domain.description,
          display_order: @goal_domain.display_order,
          is_active: @goal_domain.is_active
        }, status: :ok
      end

      private

      def set_goal_domain
        @goal_domain = GoalDomain.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Goal domain not found" }, status: :not_found
      end
    end
  end
end
