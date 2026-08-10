# frozen_string_literal: true

# Preference Assessment (SCR-012) for a six-week assessment cycle.
class Api::V1::PreferenceAssessmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!
  before_action :set_assessment_cycle
  before_action :set_preference_assessment, only: %i[show submit rankings]

  # GET /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment
  #
  # Returns the assessment with every observation recorded so far, so a teacher
  # can resume a draft where they left off (FR-036).
  #
  # @oas_include
  # @summary Get the preference assessment for an assessment cycle
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  # @response_ref (200) #/components/responses/PreferenceAssessment
  # @response_ref (404) #/components/responses/Error
  def show
    render json: { preference_assessment: serialize(@preference_assessment) }
  end

  # POST /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment
  #
  # Opens the draft assessment for the cycle. Idempotent — returns the existing
  # record with 200 if one has already been started (FR-047, FR-049).
  #
  # @oas_include
  # @summary Start the preference assessment for an assessment cycle
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  # @response_ref (201) #/components/responses/PreferenceAssessment
  # @response_ref (200) #/components/responses/PreferenceAssessment
  # @response_ref (404) #/components/responses/Error
  def create
    existing = @assessment_cycle.preference_assessment
    assessment = existing || @assessment_cycle.create_preference_assessment!

    render json: { preference_assessment: serialize(assessment) },
           status: existing ? :ok : :created
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Concurrent starts race on the unique assessment_cycle_id index; the
    # loser simply reports the assessment the winner created.
    render json: {
      preference_assessment: serialize(@assessment_cycle.reload.preference_assessment)
    }
  end

  # POST /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment/submit
  #
  # Re-ranks every context and finalises the assessment (FR-036, FR-048).
  #
  # @oas_include
  # @summary Submit the preference assessment
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  # @response_ref (200) #/components/responses/PreferenceAssessment
  # @response_ref (404) #/components/responses/Error
  # @response_ref (422) #/components/responses/Error
  def submit
    result = PreferenceAssessments::SubmitService.call(
      preference_assessment: @preference_assessment
    )

    if result.success?
      render json: { preference_assessment: serialize(result.data.reload) }
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  # GET /api/v1/assessment_cycles/:assessment_cycle_id/preference_assessment/rankings
  #
  # The ranked top-preferences list (FR-047d). Optional `context` filters to a
  # single context; optional `limit` caps the list (e.g. top 5 for the IUP
  # Assessment Summary).
  #
  # @oas_include
  # @summary Get the ranked preference list
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  # @parameter_ref #/components/parameters/PreferenceContextQuery
  # @parameter_ref #/components/parameters/PreferenceRankingLimit
  # @response_ref (200) #/components/responses/PreferenceRankings
  # @response_ref (404) #/components/responses/Error
  # @response_ref (422) #/components/responses/Error
  def rankings
    context = params[:context].presence
    if context && !PreferenceAssessment::CONTEXTS.include?(context)
      return render_error(
        "Context must be one of: #{PreferenceAssessment::CONTEXTS.join(', ')}",
        :unprocessable_entity
      )
    end

    observations = @preference_assessment
                     .ranked_observations(context: context, limit: ranking_limit)

    render json: {
      context:  context,
      rankings: PreferenceRankingSerializer.new(observations.to_a).as_json
    }
  end

  private

  def set_assessment_cycle
    @assessment_cycle = AssessmentCycle.find_by(id: params[:assessment_cycle_id])
    render_not_found("Assessment cycle not found") unless @assessment_cycle
  end

  def set_preference_assessment
    @preference_assessment = @assessment_cycle&.preference_assessment
    render_not_found("Preference assessment not found") unless @preference_assessment
  end

  def ranking_limit
    limit = params[:limit].to_i
    return nil unless limit.positive?

    [ limit, 100 ].min
  end

  def serialize(assessment)
    PreferenceAssessmentSerializer.new(assessment).as_json
  end
end
