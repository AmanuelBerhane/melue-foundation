# frozen_string_literal: true

require "csv"

module Goals
  # FR-078b: Parses predefined task analysis templates from JSON or CSV files, strings, or data payloads.
  class TaskAnalysisTemplateParser < ApplicationService
    MAX_FILE_SIZE = 5.megabytes

    def initialize(input)
      @input = input
    end

    def call
      return failure("Template data or file is required") if @input.blank?

      raw_content, format = extract_content_and_format
      return failure("Template is empty") if raw_content.blank? && !@input.is_a?(Hash)

      parsed_data = case format
      when :hash
                      normalize_hash(@input)
      when :json
                      parse_json(raw_content)
      when :csv
                      parse_csv(raw_content)
      else
                      try_parse_any(raw_content)
      end

      return failure(parsed_data) if parsed_data.is_a?(String) # Error message returned

      validation_error = validate_template(parsed_data)
      return failure(validation_error) if validation_error.present?

      success(parsed_data)
    rescue => e
      failure("Failed to parse task analysis template: #{e.message}")
    end

    private

    def extract_content_and_format
      if @input.is_a?(Hash)
        [ nil, :hash ]
      elsif @input.respond_to?(:read) # File / UploadedFile / IO
        if @input.respond_to?(:size) && @input.size > MAX_FILE_SIZE
          raise "File too large (max 5MB)"
        end

        filename = @input.respond_to?(:original_filename) ? @input.original_filename : (@input.respond_to?(:path) ? @input.path : "")
        content_type = @input.respond_to?(:content_type) ? @input.content_type : ""
        content = @input.read
        @input.rewind if @input.respond_to?(:rewind)

        format = detect_format_from_meta(filename, content_type, content)
        [ content, format ]
      elsif @input.is_a?(String)
        format = @input.strip.start_with?("{", "[") ? :json : :csv
        [ @input, format ]
      else
        [ nil, :unknown ]
      end
    end

    def detect_format_from_meta(filename, content_type, content)
      ext = File.extname(filename.to_s).downcase
      return :json if ext == ".json" || content_type.include?("json")
      return :csv if ext == ".csv" || content_type.include?("csv")

      # Content inspection fallback
      stripped = content.to_s.strip
      stripped.start_with?("{", "[") ? :json : :csv
    end

    def try_parse_any(content)
      parse_json(content)
    rescue
      parse_csv(content)
    end

    def parse_json(content)
      data = JSON.parse(content)
      normalize_hash(data)
    rescue JSON::ParserError => e
      "Invalid JSON format: #{e.message}"
    end

    def normalize_hash(data)
      data = data.with_indifferent_access if data.respond_to?(:with_indifferent_access)

      # Handle if root is an array of steps
      if data.is_a?(Array)
        steps = data.map.with_index(1) { |step, idx| normalize_step(step, idx) }
        return {
          name: nil,
          description: nil,
          mastery_criteria: {},
          steps: steps
        }
      end

      task_name = data[:task_name].presence || data[:name].presence
      description = data[:description]
      domain_name = data[:domain_name].presence || data[:domain].presence
      domain_id = data[:domain_id].presence || data[:goal_domain_id].presence
      suggested_age_range = data[:suggested_age_range].presence || data[:age_range].presence
      applicable_therapy_groups = Array(data[:applicable_therapy_groups]).compact_blank

      mastery_criteria = normalize_criteria(data[:mastery_criteria].presence || data[:overall_mastery_criteria])

      raw_steps = data[:steps] || data[:task_steps] || []
      steps = raw_steps.map.with_index(1) { |step, idx| normalize_step(step, idx) }

      {
        name: task_name,
        description: description,
        goal_domain_id: domain_id,
        domain_name: domain_name,
        suggested_age_range: suggested_age_range,
        applicable_therapy_groups: applicable_therapy_groups,
        mastery_criteria: mastery_criteria,
        goal_type: "task_analysis",
        steps: steps
      }
    end

    def parse_csv(content)
      lines = CSV.parse(content.strip, skip_blanks: true)
      return "CSV template is empty" if lines.empty?

      metadata = {}
      step_rows = []
      in_steps_table = false
      headers = nil

      lines.each do |row|
        clean_row = row.map { |c| c&.to_s&.strip }
        next if clean_row.all?(&:blank?)

        first_cell = clean_row[0]&.downcase

        if in_steps_table
          step_rows << clean_row
        elsif %w[step step_number step_num # number].include?(first_cell) || clean_row.map(&:to_s).map(&:downcase).include?("step_number")
          in_steps_table = true
          headers = clean_row.map(&:downcase)
        elsif clean_row.size == 2 && %w[task_name name description overall_mastery_criteria mastery_criteria domain domain_name age_range suggested_age_range].include?(first_cell)
          key = first_cell
          metadata[key] = clean_row[1]
        elsif clean_row[0].to_s =~ /^\d+$/ # First row is already a step starting with number
          in_steps_table = true
          headers = %w[step_number name description mastery_criteria]
          step_rows << clean_row
        else
          # Assume this row is the header row for steps table
          in_steps_table = true
          headers = clean_row.map(&:downcase)
        end
      end

      steps = []
      step_rows.each_with_index do |row, idx|
        row_hash = {}
        if headers.present?
          headers.each_with_index do |h, h_idx|
            row_hash[h] = row[h_idx]
          end
        else
          row_hash["step_number"] = row[0]
          row_hash["name"] = row[1]
          row_hash["description"] = row[2]
          row_hash["mastery_criteria"] = row[3]
        end

        step_num = (row_hash["step_number"] || row_hash["step"] || row_hash["#"]).presence&.to_i
        step_num = idx + 1 if step_num.nil? || step_num.zero?

        step_name = (row_hash["name"] || row_hash["step_name"] || row_hash["title"] || row_hash["task"]).presence
        step_desc = (row_hash["description"] || row_hash["desc"] || row_hash["details"]).presence
        step_crit = normalize_criteria(row_hash["mastery_criteria"] || row_hash["criteria"])

        next if step_name.blank? && step_desc.blank?

        steps << {
          step_number: step_num,
          name: step_name || "Step #{step_num}",
          description: step_desc,
          mastery_criteria: step_crit
        }
      end

      # Sort steps by step_number
      steps.sort_by! { |s| s[:step_number] }

      overall_criteria = normalize_criteria(metadata["overall_mastery_criteria"] || metadata["mastery_criteria"])

      {
        name: metadata["task_name"] || metadata["name"],
        description: metadata["description"],
        domain_name: metadata["domain_name"] || metadata["domain"],
        suggested_age_range: metadata["suggested_age_range"] || metadata["age_range"],
        mastery_criteria: overall_criteria,
        goal_type: "task_analysis",
        steps: steps
      }
    rescue CSV::MalformedCSVError => e
      "Invalid CSV format: #{e.message}"
    end

    def normalize_step(step, default_idx)
      step = step.with_indifferent_access if step.respond_to?(:with_indifferent_access)

      number = step[:step_number].presence || step[:step].presence || default_idx
      name = step[:name].presence || step[:title].presence || "Step #{number}"
      desc = step[:description].presence || step[:desc].presence
      criteria = normalize_criteria(step[:mastery_criteria] || step[:criteria])

      {
        step_number: number.to_i,
        name: name,
        description: desc,
        mastery_criteria: criteria
      }
    end

    def normalize_criteria(val)
      return {} if val.blank?
      return val if val.is_a?(Hash)

      if val.is_a?(String)
        begin
          parsed = JSON.parse(val)
          return parsed if parsed.is_a?(Hash)
        rescue JSON::ParserError
          # Not JSON string, store as description
        end
        { "description" => val }
      else
        { "description" => val.to_s }
      end
    end

    def validate_template(data)
      if data[:steps].blank?
        return "Template must contain at least one step"
      end

      if data[:steps].any? { |s| s[:name].blank? }
        return "All steps must have a name"
      end

      step_numbers = data[:steps].map { |s| s[:step_number] }
      if step_numbers.size != step_numbers.uniq.size
        return "Step numbers in template must be unique"
      end

      nil
    end
  end
end
