class Api::V1::SensoryActivitiesController < Api::V1::BaseController
  skip_before_action :authenticate_user!, raise: false

  # @oas_include
  # @tags Assessment
  # @summary Return all active sensory activities
  # @description Retrieves the configured list of default sensory activities for the assessment.
  # @response Success (200) [Array<Hash>]
  def index
    @activities = SensoryActivity.where(is_active: true).order(:display_order)
    render json: @activities
  end
end
