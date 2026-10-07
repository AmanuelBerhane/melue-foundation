# frozen_string_literal: true

module Api
  module V1
    class StudentProgressController < BaseController
      before_action :authenticate_user!
      before_action :require_oversight_role

      # @oas_include
      # @summary Get detailed student progress monitoring history (FR-134, SCR-DIR-006)
      # @tags Student Progress Monitoring
      # @auth [bearer_jwt]
      # @parameter id(path) [String] Required. UUID of the student.
      # @parameter page(query) [Integer] Page number for session history (default: 1).
      # @parameter per_page(query) [Integer] Sessions per page (default: 50, max: 200).
      # @response Success (200) [Hash]
      # @response_example Success (200) [JSON{
      #   "success": true,
      #   "data": {
      #     "student": { "full_name": "Abebe Kebede", "status": "active_therapy" },
      #     "current_goals": [],
      #     "session_history": {
      #       "total_sessions": 45,
      #       "completed_sessions": 43,
      #       "attendance_rate": 95.6,
      #       "pagination": { "page": 1, "per_page": 50, "total_pages": 1, "total_count": 45 },
      #       "recent_sessions": []
      #     },
      #     "trial_performance": {},
      #     "assessment_summary": {},
      #     "internal_notes": {
      #       "count": 3,
      #       "access_granted": true,
      #       "notes": []
      #     }
      #   }
      # }]
      # @response Forbidden (403) [Hash]
      # @response Not Found (404) [Hash]
      def show
        result = ::Students::ProgressMonitoringService.call(
          student_id: params[:id],
          current_user: current_user,
          page: params[:page],
          per_page: params[:per_page]
        )

        if result.success?
          render json: { success: true, data: result.data }, status: :ok
        else
          render_service_error(result)
        end
      end

      # @oas_include
      # @summary Export comprehensive student progress report PDF (FR-136, FR-156a)
      # @tags Student Progress Monitoring
      # @auth [bearer_jwt]
      # @parameter id(path) [String] Required. UUID of the student.
      # @response Success (200) [Binary] Application/PDF file stream
      # @response Forbidden (403) [Hash]
      # @response Not Found (404) [Hash]
      def progress_report
        progress_result = ::Students::ProgressMonitoringService.call(
          student_id: params[:id],
          current_user: current_user,
          page: 1,
          per_page: 200
        )

        return render_service_error(progress_result) unless progress_result.success?

        pdf_result = Reports::PdfGeneratorService.call(
          data: progress_result.data,
          report_type: "student_progress_report"
        )

        if pdf_result.success?
          student_name = progress_result.data.dig(:student, :full_name)&.parameterize(separator: "_") || "student"
          send_data pdf_result.data,
                    filename: "#{student_name}_progress_report_#{Date.today}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        else
          render json: { error: pdf_result.error }, status: :unprocessable_content
        end
      end

      private

      def render_service_error(result)
        status = case result.error
        when /forbidden/i then :forbidden
        when /not found/i then :not_found
        else :unprocessable_content
        end
        render json: { success: false, error: result.error }, status: status
      end
    end
  end
end
