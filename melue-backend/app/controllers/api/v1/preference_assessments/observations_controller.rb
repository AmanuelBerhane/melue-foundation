# frozen_string_literal: true

module Api::V1::PreferenceAssessments
  # Timer, counter, notes and custom items within a preference assessment
  # (FR-047b, FR-047e, FR-047f).
  #
  # Service calls below are root-scoped (::PreferenceAssessments) because this
  # namespace shares its name with the service module, and an unqualified
  # reference would be resolved against this module first.
  class ObservationsController < Api::V1::BaseController
    before_action :authenticate_user!
    before_action :require_staff_member!
    before_action :set_preference_assessment
    before_action :set_observation, only: %i[update destroy]

    # POST /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment/observations
    #
    # Records an item into a context. Upserts on (context, item), so tapping an
    # item that is already on the list updates it instead of duplicating it.
    # Omit preference_inventory_item_id and pass custom_item_name to add an item
    # that is not in the global catalogue (FR-047f).
    #
    # @oas_include
    # @summary Record a preference observation
    # @tags Six-Week Assessment
    # @auth [bearer_jwt]
    # @request_body_ref #/components/requestBodies/RecordPreferenceObservation
    # @response_ref (201) #/components/responses/PreferenceObservation
    # @response_ref (404) #/components/responses/Error
    # @response_ref (422) #/components/responses/Error
    def create
      result = ::PreferenceAssessments::RecordObservationService.call(
        preference_assessment:        @preference_assessment,
        context:                      params[:context],
        preference_inventory_item_id: params[:preference_inventory_item_id],
        custom_item_name:             params[:custom_item_name],
        custom_item_category:         params[:custom_item_category],
        approached:                   params[:approached],
        duration_seconds:             params[:duration_seconds],
        frequency_count:              params[:frequency_count],
        notes:                        params[:notes]
      )

      if result.success?
        render json: { observation: serialize(result.data) }, status: :created
      else
        render_error(result.error, :unprocessable_entity)
      end
    end

    # PATCH /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment/observations/:id
    #
    # Writes the accumulated timer and counter totals for one item (FR-047b) and
    # any notes the teacher added (FR-047e). Values are absolute, not deltas, so
    # a retried request is safe.
    #
    # @oas_include
    # @summary Update a preference observation
    # @tags Six-Week Assessment
    # @auth [bearer_jwt]
    # @request_body_ref #/components/requestBodies/UpdatePreferenceObservation
    # @response_ref (200) #/components/responses/PreferenceObservation
    # @response_ref (404) #/components/responses/Error
    # @response_ref (422) #/components/responses/Error
    def update
      result = ::PreferenceAssessments::UpdateObservationService.call(
        observation: @observation,
        attributes:  observation_params.to_h.symbolize_keys
      )

      if result.success?
        render json: { observation: serialize(result.data) }
      else
        render_error(result.error, :unprocessable_entity)
      end
    end

    # DELETE /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment/observations/:id
    #
    # Removes an item from the assessment and re-ranks the remaining ones.
    #
    # @oas_include
    # @summary Remove a preference observation
    # @tags Six-Week Assessment
    # @auth [bearer_jwt]
    # @response_ref (204) #/components/responses/NoContent
    # @response_ref (404) #/components/responses/Error
    # @response_ref (422) #/components/responses/Error
    def destroy
      result = ::PreferenceAssessments::DeleteObservationService.call(observation: @observation)

      if result.success?
        head :no_content
      else
        render_error(result.error, :unprocessable_entity)
      end
    end

    private

    def set_preference_assessment
      cycle = AssessmentCycle.find_by(id: params[:assessment_cycle_id])
      return render_not_found("Assessment cycle not found") unless cycle

      @preference_assessment = cycle.preference_assessment
      render_not_found("Preference assessment not found") unless @preference_assessment
    end

    # Scoped to the assessment so an id from another student's assessment
    # cannot be reached through this route.
    def set_observation
      @observation = @preference_assessment.preference_observations.find_by(id: params[:id])
      render_not_found("Observation not found") unless @observation
    end

    def observation_params
      params.permit(:approached, :duration_seconds, :frequency_count, :notes)
    end

    def serialize(observation)
      PreferenceObservationSerializer.new(observation).as_json
    end
  end
end
