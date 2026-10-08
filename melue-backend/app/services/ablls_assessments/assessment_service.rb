# frozen_string_literal: true

module AbllsAssessments
  # Core assessment operations: start, save responses, bulk save, and complete.
  #
  # FR-037 — ABLLS items organized by domain
  # FR-038 — Scoring with 0, 1, 2, N/A and optional notes
  class AssessmentService < ApplicationService
    # Start or resume an ABLLS assessment for the given cycle.
    # Idempotent: returns existing assessment if one already exists.
    #
    # @param assessment_cycle [AssessmentCycle]
    # @param staff_member [StaffMember]
    # @return [ServiceResult]
    def initialize(assessment_cycle:, staff_member:, action: :start, **kwargs)
      @assessment_cycle = assessment_cycle
      @staff_member = staff_member
      @action = action
      @kwargs = kwargs
    end

    def call
      case @action
      when :start   then start_assessment
      when :save    then save_response
      when :bulk    then bulk_save_responses
      when :complete then complete_assessment
      else failure("Unknown action: #{@action}")
      end
    end

    # Convenience class methods for each action
    def self.start(assessment_cycle:, staff_member:)
      new(assessment_cycle: assessment_cycle, staff_member: staff_member, action: :start).call
    end

    def self.save_response(ablls_assessment:, skill_item_id:, **kwargs)
      new(
        assessment_cycle: ablls_assessment.assessment_cycle,
        staff_member: ablls_assessment.staff_member,
        action: :save,
        ablls_assessment: ablls_assessment,
        skill_item_id: skill_item_id,
        **kwargs
      ).call
    end

    def self.bulk_save(ablls_assessment:, responses:)
      new(
        assessment_cycle: ablls_assessment.assessment_cycle,
        staff_member: ablls_assessment.staff_member,
        action: :bulk,
        ablls_assessment: ablls_assessment,
        responses: responses
      ).call
    end

    def self.complete(ablls_assessment:)
      new(
        assessment_cycle: ablls_assessment.assessment_cycle,
        staff_member: ablls_assessment.staff_member,
        action: :complete,
        ablls_assessment: ablls_assessment
      ).call
    end

    private

    def start_assessment
      existing = @assessment_cycle.ablls_assessment
      if existing
        return success(existing)
      end

      AbllsAssessment.transaction do
        assessment = @assessment_cycle.create_ablls_assessment!(
          staff_member: @staff_member,
          status: "draft",
          started_at: Time.current
        )

        # Pre-create response rows for all active skill items so the frontend
        # can iterate over them without needing a separate item list.
        active_items = AbllsSkillItem.active.ordered.select(:id)
        rows = active_items.map do |item|
          {
            ablls_assessment_id: assessment.id,
            ablls_skill_item_id: item.id,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        AbllsResponse.insert_all!(rows) if rows.any?

        success(assessment)
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # Concurrent starts race on the unique assessment_cycle_id index
      success(@assessment_cycle.reload.ablls_assessment)
    end

    def save_response
      assessment = @kwargs[:ablls_assessment]
      return failure("Assessment is completed and cannot be modified") unless assessment.modifiable?

      target_id = @kwargs[:response_id] || @kwargs[:skill_item_id] || @kwargs[:id]
      response = assessment.ablls_responses.find_by(id: target_id) ||
                 assessment.ablls_responses.find_by(ablls_skill_item_id: target_id)

      return failure("Skill item response not found in this assessment") unless response

      attrs = {}
      attrs[:score] = normalize_score(@kwargs[:score]) if @kwargs.key?(:score)
      attrs[:note] = @kwargs[:note] if @kwargs.key?(:note)

      response.update!(attrs)

      # Transition draft → in_progress on first score
      if assessment.status_draft? && response.score.present?
        assessment.update!(status: "in_progress")
      end

      success(response)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    end

    def bulk_save_responses
      assessment = @kwargs[:ablls_assessment]
      responses_data = @kwargs[:responses]

      return failure("Assessment is completed and cannot be modified") unless assessment.modifiable?
      return failure("No responses provided") if responses_data.blank?

      updated_responses = []

      AbllsResponse.transaction do
        responses_data.each do |entry|
          target_id = entry[:response_id] || entry["response_id"] ||
                      entry[:skill_item_id] || entry["skill_item_id"] ||
                      entry[:ablls_skill_item_id] || entry["ablls_skill_item_id"] ||
                      entry[:id] || entry["id"]

          response = assessment.ablls_responses.find_by(id: target_id) ||
                     assessment.ablls_responses.find_by(ablls_skill_item_id: target_id)

          unless response
            item = AbllsSkillItem.find_by(id: target_id) || AbllsSkillItem.find_by(identifier: target_id)
            response = assessment.ablls_responses.find_or_initialize_by(ablls_skill_item: item) if item
          end

          raise ActiveRecord::RecordNotFound, "Response not found" unless response

          attrs = {}
          if entry.key?(:score) || entry.key?("score")
            score_val = entry.key?(:score) ? entry[:score] : entry["score"]
            attrs[:score] = normalize_score(score_val)
          end
          if entry.key?(:note) || entry.key?("note")
            attrs[:note] = entry.key?(:note) ? entry[:note] : entry["note"]
          end

          response.update!(attrs) if attrs.any?
          updated_responses << response
        end

        # Transition draft → in_progress if any score was set
        if assessment.status_draft? && updated_responses.any?(&:completed?)
          assessment.update!(status: "in_progress")
        end
      end

      success(updated_responses)
    rescue ActiveRecord::RecordNotFound
      failure("One or more skill items not found in this assessment")
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    end

    def normalize_score(val)
      return nil if val.nil?

      str = val.to_s.strip
      case str.downcase
      when "0" then "0"
      when "1" then "1"
      when "2" then "2"
      when "not_applicable", "n/a", "na" then "not_applicable"
      else str
      end
    end

    def complete_assessment
      assessment = @kwargs[:ablls_assessment]

      return failure("Assessment is already completed") if assessment.status_completed?

      progress = ProgressService.call(ablls_assessment: assessment)
      progress_data = progress.data

      if progress_data[:unanswered_items] > 0
        return failure(
          "Cannot complete assessment: #{progress_data[:unanswered_items]} items remain unanswered"
        )
      end

      assessment.update!(status: "completed", completed_at: Time.current)
      success(assessment)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    end
  end
end
