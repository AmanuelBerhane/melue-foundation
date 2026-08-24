# frozen_string_literal: true

module Iups
  class ValidateService < ApplicationService
    def initialize(iup:)
      @iup = iup
      @errors = []
    end

    def call
      validate_assessment_status
      validate_required_form_fields
      validate_goal_assignments
      validate_goal_station_limits

      if @errors.any?
        failure(errors: @errors)
      else
        success(valid: true)
      end
    end

    private

    def validate_assessment_status
      unless @iup.assessment_cycle&.status_reviewed?
        @errors << "Assessment cycle must be reviewed before finalization"
      end
    end

    def validate_required_form_fields
      return unless @iup.form_submission

      form_config = @iup.form_submission.form_configuration
      fields = form_config.field_schema["fields"] || []
      required_fields = fields.select { |f| f["required"] == true }

      required_fields.each do |field|
        field_key = field["key"]
        value = @iup.form_submission.values[field_key]

        if value.nil? || value.to_s.strip.empty?
          @errors << "Required field: #{field['label']} must be completed"
        end
      end
    end

    def validate_goal_assignments
      applicable_stations = therapy_stations_for_student

      applicable_stations.each do |station|
        goal_count = @iup.student_goals.kept.where(
          therapy_station: station,
          status: "active"
        ).count

        if goal_count < 1
          @errors << "Station '#{station.name}' requires at least 1 goal for finalization"
        end
      end
    end

    def validate_goal_station_limits
      applicable_stations = therapy_stations_for_student

      applicable_stations.each do |station|
        goal_count = @iup.student_goals.kept.where(
          therapy_station: station,
          status: "active"
        ).count

        if goal_count > 2
          @errors << "Station '#{station.name}' has too many goals (max 2 allowed)"
        end
      end
    end

    def therapy_stations_for_student
      assigned_station_ids = @iup.student_goals.kept.select(:therapy_station_id).distinct.pluck(:therapy_station_id)
      TherapyStation.where(id: assigned_station_ids, discarded_at: nil)
    end
  end
end
