# app/services/charts/export_service.rb
module Charts
  class ExportService
    def initialize(student, chart_type, goal_id: nil, start_date: nil, end_date: nil)
      @student = student
      @chart_type = chart_type
      @goal_id = goal_id
      @start_date = start_date || 30.days.ago
      @end_date = end_date || Time.current
    end

    def call
      data = fetch_chart_data
      return { error: data[:error] } if data[:error].present?

      { data: data }
    end

    def generate_pdf
      data = call
      return data[:error] if data[:error].present?

      begin
        pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape)

        pdf.repeat(:all) do
          pdf.text "Melue Foundation", size: 16, style: :bold
          pdf.text "Chart Export - #{@chart_type.titleize}", size: 14
          pdf.text "Student: #{@student.full_name}", size: 12
          pdf.text "Date Range: #{@start_date.strftime('%B %d, %Y')} - #{@end_date.strftime('%B %d, %Y')}"
          pdf.move_down 10
          pdf.stroke_horizontal_rule
          pdf.move_down 10
        end

        generate_data_table(pdf, data[:data])

        pdf.repeat(:all) do
          pdf.move_down 10
          pdf.stroke_horizontal_rule
          pdf.text "Generated: #{Time.current.strftime('%B %d, %Y at %H:%M')}", size: 8, align: :center
        end

        pdf.render
      rescue => e
        { error: "Failed to generate PDF: #{e.message}" }
      end
    end

    def generate_png
      data = call
      return data[:error] if data[:error].present?

      begin
        # Simple placeholder image using RMagick if available
        # For now, return a structured placeholder
        {
          message: "PNG export will be available soon",
          chart_type: @chart_type,
          data: data[:data],
          placeholder: true
        }
      rescue => e
        { error: "Failed to generate PNG: #{e.message}" }
      end
    end

    private

    def fetch_chart_data
      case @chart_type
      when "goal_progress"
        student_goal = StudentGoal.find_by(id: @goal_id, student_id: @student.id)
        return { error: "Goal not found" } unless student_goal

        service = Charts::GoalProgressService.new(student_goal, @start_date, @end_date)
        result = service.call
        return { error: result.error } unless result.success?
        result.data
      when "trial_distribution"
        student_goal = StudentGoal.find_by(id: @goal_id, student_id: @student.id)
        return { error: "Goal not found" } unless student_goal

        service = Charts::TrialDistributionService.new(student_goal, @start_date, @end_date)
        result = service.call
        return { error: result.error } unless result.success?
        result.data
      when "behavior_trends"
        service = Charts::BehaviorTrendsService.new(@student, @start_date, @end_date)
        result = service.call
        return { error: result.error } unless result.success?
        result.data
      when "assessment_summary"
        service = Charts::AssessmentSummaryService.new(@student)
        result = service.call
        return { error: result.error } unless result.success?
        result.data
      else
        { error: "Unknown chart type: #{@chart_type}" }
      end
    end

    def generate_data_table(pdf, data)
      pdf.move_down 20
      pdf.text "Data Details", size: 14, style: :bold
      pdf.move_down 10

      table_data = [ [ "Date", "Value", "Notes" ] ]

      case @chart_type
      when "goal_progress"
        data[:data_points]&.each do |point|
          table_data << [
            point[:date],
            "#{point[:success_rate]}%",
            "Total: #{point[:total_trials]} trials"
          ]
        end
      when "trial_distribution"
        data[:distribution]&.each do |item|
          table_data << [
            item[:prompt_level],
            item[:count],
            "#{item[:percentage]}% of total"
          ]
        end
      when "behavior_trends"
        data[:data_points]&.each do |point|
          table_data << [
            point[:date],
            point[:total_incidents],
            "Categories: #{point[:categories]&.join(', ')}"
          ]
        end
      when "assessment_summary"
        data[:assessments]&.each do |key, value|
          table_data << [
            key.titleize,
            value[:score] || "N/A",
            value[:status] || "Not completed"
          ]
        end
      end

      if table_data.length > 1
        pdf.table(table_data,
          header: true,
          width: 700,
          cell_style: { size: 10 },
          row_colors: [ "F0F0F0", "FFFFFF" ]
        ) do
          row(0).style(background: "333333", text_color: "FFFFFF", font_style: :bold)
        end
      else
        pdf.text "No detailed data available", size: 10, color: "666666"
      end
    end
  end
end
