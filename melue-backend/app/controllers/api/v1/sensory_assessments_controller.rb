class Api::V1::SensoryAssessmentsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, raise: false
  before_action :set_assessment, only: [ :show, :update, :submit ]

  # @oas_include
  # @tags Assessment
  # @summary Get a specific Sensory Assessment
  # @description Retrieves a sensory assessment by ID, including its records and generated summary.
  # @parameter id(path) [String] The UUID of the assessment
  # @response Success (200) [Hash]
  def show
    render json: @assessment.as_json(
      include: :sensory_assessment_records,
      methods: :summary
    )
  end

  # @oas_include
  # @tags Assessment
  # @summary Create a new Draft Sensory Assessment
  # @description Creates a draft sensory assessment and its associated records.
  # @request_body Assessment Payload [Hash]
  # @response Created (201) [Hash]
  def create
    @assessment = SensoryAssessment.new(assessment_params)

    if @assessment.save
      render json: @assessment.as_json(include: :sensory_assessment_records), status: :created
    else
      render json: { errors: @assessment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @tags Assessment
  # @summary Update a Draft Sensory Assessment
  # @description Updates an existing draft sensory assessment.
  # @parameter id(path) [String] The UUID of the assessment
  # @request_body Assessment Payload [Hash]
  # @response Success (200) [Hash]
  def update
    if @assessment.update(assessment_params)
      render json: @assessment.as_json(include: :sensory_assessment_records)
    else
      render json: { errors: @assessment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @tags Assessment
  # @summary Submit and Finalize a Sensory Assessment
  # @description Marks the assessment as complete and generates the final summary.
  # @parameter id(path) [String] The UUID of the assessment
  # @response Success (200) [Hash]
  def submit
    if @assessment.submit!
      render json: @assessment.as_json(
        include: :sensory_assessment_records,
        methods: :summary
      )
    else
      render json: { errors: @assessment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_assessment
    @assessment = SensoryAssessment.find(params[:id])
  end

  def assessment_params
    params.require(:sensory_assessment).permit(
      :student_id,
      :status,
      sensory_assessment_records_attributes: [
        :id, :sensory_activity_id, :engagement_level, :response_reaction, :remark, :_destroy
      ]
    )
  end
end
