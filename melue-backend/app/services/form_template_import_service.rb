class FormTemplateImportService < ApplicationService
  MAX_FILE_SIZE = 10.megabytes

  def initialize(form_configuration, file)
    @form = form_configuration
    @file = file
  end

  def call
    validate_file
    return failure(@errors) if @errors.any?

    parsed_schema = parse_json
    return failure("Invalid JSON format") unless parsed_schema

    ActiveRecord::Base.transaction do
      @form.field_schema = parsed_schema
      @form.revision_number += 1
      @form.save!
    end

    success(@form)
  rescue JSON::ParserError => e
    failure("JSON parse error: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  def validate_file
    @errors = []
    @errors << "File is required" if @file.blank?
    return if @file.blank?

    @errors << "File too large (max 10MB)" if @file.size > MAX_FILE_SIZE
    @errors << "Content-Type must be application/json" unless @file.content_type == "application/json"
  end

  def parse_json
    JSON.parse(@file.read)
  end
end
