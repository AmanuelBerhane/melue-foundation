module Api
  module V1
    class ReportsController < BaseController
      # @oas_include
      # @summary Get foundation overview metrics
      # @tags Reports
      # @auth [bearer_jwt]
      # @parameter start_date(query) [String] Start date for metrics (YYYY-MM-DD)
      # @parameter end_date(query) [String] End date for metrics (YYYY-MM-DD)
      # @response Success (200) [Hash]
      # @response_example Success (200) [JSON{ "data": { "total_active_students": 50, "goals_mastered_this_month": 12, "behavior_incident_trends": [], "teacher_performance": [], "program_distribution": { "Regular": 40, "Pulled Out": 10 } } }]
      def foundation_overview
        start_date = params[:start_date] ? Date.parse(params[:start_date]).beginning_of_day : Time.current.beginning_of_month
        end_date = params[:end_date] ? Date.parse(params[:end_date]).end_of_day : Time.current.end_of_month

        result = Reports::FoundationOverviewService.call(start_date: start_date, end_date: end_date)

        if result.success?
          if params[:export].present?
            handle_export(result.data, params[:export], "foundation_overview")
          else
            render json: { data: result.data }, status: :ok
          end
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      rescue ArgumentError => e
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      # @oas_include
      # @summary Get filtered session summaries
      # @tags Reports
      # @auth [bearer_jwt]
      # @parameter start_date(query) [String] Filter by start date (YYYY-MM-DD)
      # @parameter end_date(query) [String] Filter by end date (YYYY-MM-DD)
      # @parameter teacher_id(query) [String] Filter by specific teacher
      # @parameter station_id(query) [String] Filter by specific station
      # @parameter student_id(query) [String] Filter by specific student
      # @parameter sort_by(query) [String] Field to sort by (e.g., started_at). default: (started_at)
      # @parameter sort_direction(query) [String] Sort direction (asc/desc). default: (desc)
      # @response Success (200) [Array<Hash>]
      # @response_example Success (200) [JSON{ "data": [ { "id": "123", "status": "completed", "started_at": "...", "teacher": { "name": "Jane" } } ] }]
      def session_summaries
        result = Reports::SessionSummariesService.call(
          start_date: params[:start_date],
          end_date: params[:end_date],
          teacher_id: params[:teacher_id],
          station_id: params[:station_id],
          student_id: params[:student_id],
          sort_by: params[:sort_by],
          sort_direction: params[:sort_direction]
        )

        if result.success?
          if params[:export].present?
            handle_export(result.data, params[:export], "session_summaries")
          else
            render json: { data: result.data }, status: :ok
          end
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      rescue ArgumentError => e
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      # @oas_include
      # @summary Get consolidated weekly summaries
      # @tags Reports
      # @auth [bearer_jwt]
      # @parameter start_date(query) [String] Filter by start date (YYYY-MM-DD)
      # @parameter end_date(query) [String] Filter by end date (YYYY-MM-DD)
      # @parameter teacher_id(query) [String] Filter by specific teacher
      # @parameter student_id(query) [String] Filter by specific student
      # @response Success (200) [Array<Hash>]
      def weekly_summaries
        result = Reports::WeeklySummariesService.call(
          start_date: params[:start_date],
          end_date: params[:end_date],
          teacher_id: params[:teacher_id],
          student_id: params[:student_id]
        )

        if result.success?
          if params[:export].present?
            handle_export(result.data, params[:export], "weekly_summaries")
          else
            render json: { data: result.data }, status: :ok
          end
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      rescue ArgumentError => e
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      # @oas_include
      # @summary Get student progress for bi-annual report
      # @tags Reports
      # @auth [bearer_jwt]
      # @parameter student_id(query) [String] Required. ID of the student.
      # @parameter start_date(query) [String] Filter by start date (YYYY-MM-DD). Defaults to 6 months ago.
      # @parameter end_date(query) [String] Filter by end date (YYYY-MM-DD). Defaults to today.
      # @response Success (200) [Hash]
      def student_progress
        return render json: { error: "student_id is required" }, status: :bad_request unless params[:student_id]

        result = Reports::StudentProgressService.call(
          student_id: params[:student_id],
          start_date: params[:start_date],
          end_date: params[:end_date]
        )

        if result.success?
          if params[:export].present?
            handle_export(result.data, params[:export], "student_progress")
          else
            render json: { data: result.data }, status: :ok
          end
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      rescue ArgumentError => e
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      private

      def handle_export(data, format, report_type)
        export_result = Reports::ExportService.call(data: data, format: format, report_type: report_type)

        if export_result.success?
          content_type = format.to_s.downcase == "csv" ? "text/csv" : "application/pdf"
          send_data export_result.data,
                    filename: "#{report_type}_#{Date.today}.#{format}",
                    type: content_type
        else
          render json: { error: export_result.error }, status: :unprocessable_entity
        end
      end
    end
  end
end
