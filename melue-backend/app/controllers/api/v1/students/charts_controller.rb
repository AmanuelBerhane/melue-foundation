# app/controllers/api/v1/students/charts_controller.rb
class Api::V1::Students::ChartsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_program_director!
  before_action :set_student
  before_action :set_date_range, only: [ :goal_progress, :trial_distribution, :behavior_trends ]

  # @oas_include
  # @summary Get goal progress chart data
  # @tags Charts
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @parameter goal_id(query) [!String] Student Goal ID
  # @parameter start_date(query) [String] Start date (YYYY-MM-DD)
  # @parameter end_date(query) [String] End date (YYYY-MM-DD)
  #
  # @response Success (200) [Hash{ goal_id: String, data_points: Array }]
  def goal_progress
    student_goal = StudentGoal.find_by(id: params[:goal_id], student_id: @student.id)
    return render json: { error: "Goal not found for this student" }, status: :not_found unless student_goal

    service = Charts::GoalProgressService.new(student_goal, @start_date, @end_date)
    result = service.call

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_content
    end
  end

  # @oas_include
  # @summary Get trial distribution chart data
  # @tags Charts
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @parameter goal_id(query) [!String] Student Goal ID
  # @parameter start_date(query) [String] Start date (YYYY-MM-DD)
  # @parameter end_date(query) [String] End date (YYYY-MM-DD)
  #
  # @response Success (200) [Hash{ distribution: Array }]
  def trial_distribution
    student_goal = StudentGoal.find_by(id: params[:goal_id], student_id: @student.id)
    return render json: { error: "Goal not found for this student" }, status: :not_found unless student_goal

    service = Charts::TrialDistributionService.new(student_goal, @start_date, @end_date)
    result = service.call

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_content
    end
  end

  # @oas_include
  # @summary Get behavior trends chart data
  # @tags Charts
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @parameter start_date(query) [String] Start date (YYYY-MM-DD)
  # @parameter end_date(query) [String] End date (YYYY-MM-DD)
  #
  # @response Success (200) [Hash{ data_points: Array }]
  def behavior_trends
    service = Charts::BehaviorTrendsService.new(@student, @start_date, @end_date)
    result = service.call

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_content
    end
  end

  # @oas_include
  # @summary Get assessment summary for radar chart
  # @tags Charts
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  #
  # @response Success (200) [Hash{ assessments: Hash }]
  def assessment_summary
    service = Charts::AssessmentSummaryService.new(@student)
    result = service.call

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_content
    end
  end

  # @oas_include
  # @summary Export chart data
  # @tags Charts
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @request_body Export data [Hash{ chart_type: !String, goal_id: String, start_date: String, end_date: String, format: String }]
  #
  # @response Success (200) [File/JSON]
  def export
    chart_type = params[:chart_type]
    goal_id = params[:goal_id]
    format = params[:format] || "json"
    start_date = params[:start_date]&.to_date || 30.days.ago
    end_date = params[:end_date]&.to_date || Time.current

    # Validate chart_type
    unless %w[goal_progress trial_distribution behavior_trends assessment_summary].include?(chart_type)
      return render json: { error: "Invalid chart type. Must be one of: goal_progress, trial_distribution, behavior_trends, assessment_summary" },
                    status: :bad_request
    end

    # Validate goal_id for chart types that require it
    if %w[goal_progress trial_distribution].include?(chart_type) && goal_id.blank?
      return render json: { error: "goal_id is required for #{chart_type}" },
                    status: :bad_request
    end

    # Create export service
    export_service = Charts::ExportService.new(
      @student,
      chart_type,
      goal_id: goal_id,
      start_date: start_date,
      end_date: end_date
    )

    case format
    when "pdf"
      pdf_data = export_service.generate_pdf
      if pdf_data.is_a?(String)
        send_data pdf_data,
          filename: "#{chart_type}_#{@student.id}_#{Date.current}.pdf",
          type: "application/pdf",
          disposition: "attachment"
      elsif pdf_data.is_a?(Hash) && pdf_data[:error]
        render json: { error: pdf_data[:error] },
              status: :unprocessable_content
      else
        render json: { error: "Failed to generate PDF" },
              status: :unprocessable_content
      end
    when "png"
      png_data = export_service.generate_png

      # Check if it's a placeholder (hash) or actual PNG data (string)
      if png_data.is_a?(String)
        send_data png_data,
          filename: "#{chart_type}_#{@student.id}_#{Date.current}.png",
          type: "image/png",
          disposition: "attachment"
      elsif png_data.is_a?(Hash) && png_data[:error]
        render json: { error: png_data[:error] },
              status: :unprocessable_content
      elsif png_data.is_a?(Hash) && png_data[:placeholder]
        # For MVP, return JSON with placeholder message
        render json: {
          message: png_data[:message],
          chart_type: chart_type,
          data: png_data[:data],
          exported_at: Time.current,
          format: "png_placeholder"
        }
      else
        render json: { error: "Failed to generate PNG" },
              status: :unprocessable_content
      end
    else
      # Default: JSON export
      result = export_service.call
      if result[:error].present?
        render json: { error: result[:error] },
              status: :not_found
      else
        render json: {
          chart_type: chart_type,
          data: result[:data],
          exported_at: Time.current,
          format: "json"
        }
      end
    end
  end

  # @oas_include
  # @summary Share chart with parents
  # @tags Charts
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @request_body Share data [Hash{ chart_type: !String, goal_id: String, start_date: String, end_date: String, parent_email: String, message: String }]
  #
  # @response Success (200) [Hash{ message: String, share_link: String }]
  def share
    # TODO: Implement parent communication module integration
    # For now, return a shareable link placeholder
    share_token = SecureRandom.hex(16)

    render json: {
      message: "Chart shared with parent(s)",
      share_link: "#{request.base_url}/api/v1/parents/shared_charts/#{share_token}",
      expires_at: 7.days.from_now
    }
  end

  private

  def set_student
    @student = Student.find(params[:student_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def set_date_range
    @start_date = params[:start_date]&.to_date || 30.days.ago
    @end_date = params[:end_date]&.to_date || Time.current
  end

  def fetch_chart_data(chart_type, goal_id)
    case chart_type
    when "goal_progress"
      student_goal = StudentGoal.find_by(id: goal_id, student_id: @student.id)
      return { error: "Goal not found" } unless student_goal

      service = Charts::GoalProgressService.new(student_goal, @start_date, @end_date)
      service.call.data
    when "trial_distribution"
      student_goal = StudentGoal.find_by(id: goal_id, student_id: @student.id)
      return { error: "Goal not found" } unless student_goal

      service = Charts::TrialDistributionService.new(student_goal, @start_date, @end_date)
      service.call.data
    when "behavior_trends"
      service = Charts::BehaviorTrendsService.new(@student, @start_date, @end_date)
      service.call.data
    when "assessment_summary"
      service = Charts::AssessmentSummaryService.new(@student)
      service.call.data
    else
      { error: "Unknown chart type: #{chart_type}" }
    end
  end

  def require_program_director!
    unless current_staff_member&.role_program_director?
      render json: { error: "Unauthorized - Program Director access required" }, status: :forbidden
    end
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end
end
