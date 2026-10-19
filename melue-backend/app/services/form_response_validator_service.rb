# frozen_string_literal: true

class FormResponseValidatorService < ApplicationService
  PHONE_REGEX = /\A\+?[1-9]\d{1,14}\z/

  def initialize(form_config:, response_payload:)
    @form_config = form_config
    @field_schema = form_config.field_schema || {}
    @fields = @field_schema["fields"] || []
    @raw_payload = response_payload.respond_to?(:to_unsafe_h) ? response_payload.to_unsafe_h.deep_stringify_keys : response_payload.to_h.deep_stringify_keys
    @errors = {}
    @sanitized_data = {}
  end

  def call
    validate_payload!

    if @errors.empty?
      success(@sanitized_data)
    else
      failure(@errors, :unprocessable_entity)
    end
  end

  private

  def validate_payload!
    @fields.each do |field|
      field_id = field["id"].to_s
      field_type = field["type"].to_s.downcase.underscore
      validation = field["validation"] || {}

      # Ignore display-only non-input components (e.g. section_header, divider)
      next if field["is_display_only"] == true || field_type.in?(%w[section_header divider])

      value = @raw_payload[field_id]

      # 1. Required Presence Validation
      if validation["required"] && blank_value?(value, field_type)
        add_error(field_id, "#{field['label'] || field_id} is required")
        next
      end

      # Skip deep validation if field is optional and omitted
      next if value.nil? && !validation["required"]

      # 2. Type-Specific Cast and Validation
      cast_and_validate_field!(field, field_id, field_type, value, validation)
    end
  end

  def cast_and_validate_field!(field, field_id, type, value, validation)
    case type
    when "textarea", "text"
      validate_text!(field_id, value, validation)
    when "checkbox_group"
      validate_checkbox_group!(field, field_id, value, validation)
    when "switch"
      validate_switch!(field_id, value)
    when "phone"
      validate_phone!(field_id, value, validation)
    when "image_picker"
      validate_image_picker!(field_id, value, validation)
    when "number"
      validate_number!(field_id, value, validation)
    when "radio", "dropdown"
      validate_enum!(field, field_id, value)
    when "checkbox"
      validate_switch!(field_id, value)
    when "file", "file_upload"
      validate_file!(field_id, value, validation)
    else
      @sanitized_data[field_id] = value
    end
  end

  # ==========================================
  # TYPE VALIDATORS
  # ==========================================

  def validate_text!(field_id, value, validation)
    str = value.to_s.strip
    if validation["min_length"] && str.length < validation["min_length"].to_i
      add_error(field_id, "Must be at least #{validation['min_length']} characters")
    elsif validation["max_length"] && str.length > validation["max_length"].to_i
      add_error(field_id, "Must not exceed #{validation['max_length']} characters")
    else
      @sanitized_data[field_id] = str
    end
  end

  def validate_checkbox_group!(field, field_id, value, validation)
    unless value.is_a?(Array)
      add_error(field_id, "Must be an array of selected options")
      return
    end

    allowed_options = (field["options"] || []).map do |opt|
      opt.is_a?(Hash) ? opt["value"].to_s : opt.to_s
    end

    invalid_choices = value.map(&:to_s) - allowed_options
    if allowed_options.any? && invalid_choices.any?
      add_error(field_id, "Invalid selection: #{invalid_choices.join(', ')}")
      return
    end

    if validation["min_select"] && value.size < validation["min_select"].to_i
      add_error(field_id, "Please select at least #{validation['min_select']} options")
    elsif validation["max_select"] && value.size > validation["max_select"].to_i
      add_error(field_id, "Cannot select more than #{validation['max_select']} options")
    else
      @sanitized_data[field_id] = value.map(&:to_s).uniq
    end
  end

  def validate_switch!(field_id, value)
    if [ true, "true", 1, "1" ].include?(value)
      @sanitized_data[field_id] = true
    elsif [ false, "false", 0, "0" ].include?(value)
      @sanitized_data[field_id] = false
    else
      add_error(field_id, "Must be a valid boolean true/false")
    end
  end

  def validate_phone!(field_id, value, validation)
    cleaned = value.to_s.gsub(/[\s()-]/, "")
    regex = validation["pattern"] ? Regexp.new(validation["pattern"]) : PHONE_REGEX

    if cleaned !~ regex
      add_error(field_id, "Invalid phone number format")
    else
      @sanitized_data[field_id] = cleaned
    end
  end

  def validate_image_picker!(field_id, value, validation)
    return if value.blank? && !validation["required"]

    if value.is_a?(String) && (value.start_with?("http") || value.start_with?("data:image/") || value.start_with?("file://") || value.match?(/\A[a-zA-Z0-9_\-\.\/]+\.(png|jpe?g|webp|heic)\z/i) || value.start_with?("ey"))
      @sanitized_data[field_id] = value
    else
      add_error(field_id, "Invalid image reference or upload identifier")
    end
  end

  def validate_file!(field_id, value, validation)
    return if value.blank? && !validation["required"]
    @sanitized_data[field_id] = value.to_s
  end

  def validate_number!(field_id, value, validation)
    num = Float(value) rescue nil
    if num.nil?
      add_error(field_id, "Must be a valid number")
    else
      @sanitized_data[field_id] = num
    end
  end

  def validate_enum!(field, field_id, value)
    allowed = (field["options"] || []).map { |o| o.is_a?(Hash) ? o["value"].to_s : o.to_s }
    if allowed.empty? || allowed.include?(value.to_s)
      @sanitized_data[field_id] = value.to_s
    else
      add_error(field_id, "Option not recognized")
    end
  end

  # ==========================================
  # HELPERS
  # ==========================================

  def blank_value?(value, field_type)
    return false if field_type.in?(%w[switch checkbox]) && (value == true || value == false)
    return true if value.nil?
    return true if value.is_a?(Array) && value.empty?
    return true if value.is_a?(String) && value.strip.empty?
    false
  end

  def add_error(field_id, message)
    @errors[field_id] ||= []
    @errors[field_id] << message
  end
end
