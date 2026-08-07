# frozen_string_literal: true

# Serves the default preference item catalogue (SRS 3.3.4).
class Api::V1::PreferenceInventoryItemsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!

  # GET /api/v1/preference_inventory_items
  #
  # Returns the active inventory grouped by category, which is how SCR-012
  # renders it (FR-047a).
  #
  # @oas_include
  # @summary List the preference item inventory grouped by category
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  # @response_ref (200) #/components/responses/PreferenceInventory
  def index
    items = PreferenceInventoryItem.active.ordered.to_a

    categories = items.group_by(&:category).map do |category, category_items|
      {
        category: category,
        items:    PreferenceInventoryItemSerializer.new(category_items).as_json
      }
    end

    render json: { categories: categories }
  end
end
