# frozen_string_literal: true

# ABLLS Skills Assessment (SCR-TEA-002) for a six-week assessment cycle.
#
# FR-037 — Domain-based navigation
# FR-038 — Scoring (0, 1, 2, N/A) with optional notes
# FR-039 — Automatic Need Analysis Summary
# FR-040 — Assessment completion progress percentage
class Api::V1::AbllsAssessmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!
  before_action :set_assessment_cycle, only: %i[show create]
  before_action :set_ablls_assessment, only: %i[update_response bulk_update_responses complete]

  # GET /api/v1/assessment_cycles/:assessment_cycle_id/ablls_assessment
  #
  # Returns the full assessment payload: domains, items, scores, progress,
  # need analysis, and score metadata. Supports draft/resume (FR-036).
  #
  # @oas_include
  # @summary Get the ABLLS assessment for an assessment cycle
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  def show
    assessment = @assessment_cycle.ablls_assessment
    return render_not_found("ABLLS assessment not found") unless assessment

    render json: { ablls_assessment: AbllsAssessmentSerializer.new(assessment).as_json }
  end

  # POST /api/v1/assessment_cycles/:assessment_cycle_id/ablls_assessment
  #
  # Starts the ABLLS assessment for the cycle. Idempotent — returns the
  # existing record with 200 if already started.
  #
  # @oas_include
  # @summary Start the ABLLS assessment for an assessment cycle
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  def create
    authorize_student_access!(@assessment_cycle.student)
    return if performed?

    result = AbllsAssessments::AssessmentService.start(
      assessment_cycle: @assessment_cycle,
      staff_member: current_staff_member
    )

    if result.success?
      assessment = result.data
      was_new = assessment.previously_new_record?
      render json: { ablls_assessment: AbllsAssessmentSerializer.new(assessment).as_json },
             status: was_new ? :created : :ok
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  # PATCH /api/v1/ablls_assessments/:ablls_assessment_id/responses/:id
  #
  # Updates a single skill response (score and/or note).
  #
  # @oas_include
  # @summary Update a single ABLLS skill response
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  def update_response
    authorize_assessment_modification!
    return if performed?

    result = AbllsAssessments::AssessmentService.save_response(
      ablls_assessment: @ablls_assessment,
      skill_item_id: params[:response_id],
      **response_params
    )

    if result.success?
      render json: { response: AbllsResponseSerializer.new(result.data).as_json }
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  # PATCH /api/v1/ablls_assessments/:ablls_assessment_id/responses/bulk
  #
  # Transactional bulk update of skill responses. If one fails validation,
  # the entire batch is rolled back.
  #
  # @oas_include
  # @summary Bulk update ABLLS skill responses
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  def bulk_update_responses
    authorize_assessment_modification!
    return if performed?

    raw_responses = params[:responses] || []
    responses_list = raw_responses.map do |entry|
      entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h.symbolize_keys : entry.to_h.symbolize_keys
    end

    result = AbllsAssessments::AssessmentService.bulk_save(
      ablls_assessment: @ablls_assessment,
      responses: responses_list
    )

    if result.success?
      render json: { responses: AbllsResponseSerializer.new(result.data).as_json }
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  # POST /api/v1/ablls_assessments/:ablls_assessment_id/complete
  #
  # Finalises the assessment. Rejects completion if unanswered items remain.
  #
  # @oas_include
  # @summary Complete the ABLLS assessment
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  def complete
    authorize_assessment_modification!
    return if performed?

    result = AbllsAssessments::AssessmentService.complete(
      ablls_assessment: @ablls_assessment
    )

    if result.success?
      render json: { ablls_assessment: AbllsAssessmentSerializer.new(result.data).as_json }
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  # GET /api/v1/ablls_assessments/score_options
  #
  # Returns the score metadata (labels, colors, prompts) so the frontend
  # does not have to duplicate clinical definitions.
  #
  # @oas_include
  # @summary Get ABLLS score options metadata
  # @tags Six-Week Assessment
  # @auth [bearer_jwt]
  def score_options
    render json: { score_options: AbllsAssessmentSerializer::SCORE_OPTIONS }
  end

  private

  def set_assessment_cycle
    @assessment_cycle = AssessmentCycle.find_by(id: params[:assessment_cycle_id])
    render_not_found("Assessment cycle not found") unless @assessment_cycle
  end

  def set_ablls_assessment
    assessment_id = params[:ablls_assessment_id] || params[:id]
    @ablls_assessment = AbllsAssessment.find_by(id: assessment_id)
    render_not_found("ABLLS assessment not found") unless @ablls_assessment
  end

  def response_params
    permitted = {}
    permitted[:score] = params[:score] if params.key?(:score)
    permitted[:note] = params[:note] if params.key?(:note)
    permitted
  end

  # Authorization: verify the staff member has a relationship with the student.
  # Admin/coordinator/director roles bypass the assignment check.
  def authorize_student_access!(student)
    return if current_staff_member.can_view_all_students?

    unless TeacherStudentAssignment.exists?(
      teacher_id: current_staff_member.id,
      student_id: student.id
    )
      render_error("You are not authorized to assess this student", :forbidden)
    end
  end

  def authorize_assessment_modification!
    return render_error("ABLLS assessment not found", :not_found) unless @ablls_assessment
    return render_error("Assessment is completed and cannot be modified", :forbidden) unless @ablls_assessment.modifiable?

    authorize_student_access!(@ablls_assessment.student)
  end
end
