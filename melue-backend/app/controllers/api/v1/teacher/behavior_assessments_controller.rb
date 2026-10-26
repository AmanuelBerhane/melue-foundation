# frozen_string_literal: true

# app/controllers/api/v1/teacher/behavior_assessments_controller.rb
module Api
  module V1
    module Teacher
      class BehaviorAssessmentsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_student

        def show
          mass_assessment = MassAssessment.where(student_id: @student.id).order(created_at: :desc).first
          fast_assessment = FastAssessment.where(student_id: @student.id).order(created_at: :desc).first

          target_assessments = @behavior_assessment.behavior_target_assessments.kept

          target_behaviors_data = target_assessments.map do |bta|
            {
              id: bta.id.to_s,
              behavior_name: bta.behavior_name,
              behaviorName: bta.behavior_name,
              mass_responses: bta.mass_responses || {},
              massAnswers: bta.mass_responses || {},
              fast_responses: bta.fast_responses || {},
              fastAnswers: bta.fast_responses || {},
              function_scores: bta.function_scores || {},
              scores: bta.function_scores || {},
              dominant_function: bta.dominant_function || "Sensory",
              hypothesized_function: bta.hypothesized_function || "Sensory",
              risk_indicators: bta.risk_indicators || {},
              status: bta.status
            }
          end

          # If no multi-records yet, build from flat records for compatibility
          if target_behaviors_data.empty? && (mass_assessment&.responses.present? || fast_assessment&.responses.present?)
            combined_sc = {
              sensory: mass_assessment&.function_scores&.dig(:sensory).to_i + fast_assessment&.function_scores&.dig(:sensory).to_i,
              escape: mass_assessment&.function_scores&.dig(:escape).to_i + fast_assessment&.function_scores&.dig(:escape).to_i,
              attention: mass_assessment&.function_scores&.dig(:attention).to_i + fast_assessment&.function_scores&.dig(:attention).to_i,
              tangible: mass_assessment&.function_scores&.dig(:tangible).to_i + fast_assessment&.function_scores&.dig(:tangible).to_i
            }
            target_behaviors_data = [
              {
                id: "default",
                behavior_name: "Target Behavior 1",
                behaviorName: "Target Behavior 1",
                mass_responses: mass_assessment&.responses || {},
                massAnswers: mass_assessment&.responses || {},
                fast_responses: fast_assessment&.responses || {},
                fastAnswers: fast_assessment&.responses || {},
                function_scores: combined_sc,
                scores: combined_sc,
                dominant_function: mass_assessment&.dominant_function || "Sensory",
                hypothesized_function: fast_assessment&.hypothesized_function || "Sensory",
                risk_indicators: fast_assessment&.risk_indicators || {},
                status: mass_assessment&.status || "draft"
              }
            ]
          end

          mass_sc = mass_assessment&.function_scores || { sensory: 0, escape: 0, attention: 0, tangible: 0 }
          fast_sc = fast_assessment&.function_scores || { sensory: 0, escape: 0, attention: 0, tangible: 0 }

          combined_scores = {
            sensory: mass_sc[:sensory].to_i + fast_sc[:sensory].to_i,
            escape: mass_sc[:escape].to_i + fast_sc[:escape].to_i,
            attention: mass_sc[:attention].to_i + fast_sc[:attention].to_i,
            tangible: mass_sc[:tangible].to_i + fast_sc[:tangible].to_i
          }

          render json: {
            status: "success",
            data: {
              student_id: @student.id,
              student_name: @student.full_name,
              massAnswers: mass_assessment&.responses || target_behaviors_data.first&.dig(:massAnswers) || {},
              fastAnswers: fast_assessment&.responses || target_behaviors_data.first&.dig(:fastAnswers) || {},
              target_behaviors: target_behaviors_data,
              targetBehaviors: target_behaviors_data,
              records: [],
              scores: combined_scores,
              function_scores: combined_scores,
              mass_scores: mass_sc,
              fast_scores: fast_sc,
              dominant_function: mass_assessment&.dominant_function || target_behaviors_data.first&.dig(:dominant_function) || "Sensory",
              hypothesized_function: fast_assessment&.hypothesized_function || target_behaviors_data.first&.dig(:hypothesized_function) || "Sensory",
              risk_indicators: fast_assessment&.risk_indicators || target_behaviors_data.first&.dig(:risk_indicators) || {},
              status: @behavior_assessment&.status || mass_assessment&.status || "draft"
            }
          }
        end

        def create
          is_submitting = params[:status] == "submitted" || params[:status] == "completed"

          # Multi-behavior payload support
          raw_targets = params[:target_behaviors] || params[:targetBehaviors] || params[:behaviors]

          if raw_targets.present? && raw_targets.is_a?(Array)
            # Validate completion if submitting
            if is_submitting
              raw_targets.each do |tb|
                bname = tb[:behavior_name] || tb[:behaviorName] || tb[:name] || "Configured behavior"
                m_ans = tb[:massAnswers] || tb[:mass_responses] || {}
                f_ans = tb[:fastAnswers] || tb[:fast_responses] || {}
                m_count = m_ans.respond_to?(:keys) ? m_ans.keys.count { |k| m_ans[k].present? } : 0
                f_count = f_ans.respond_to?(:keys) ? f_ans.keys.count { |k| !f_ans[k].nil? } : 0

                if m_count < 12 || f_count < 8
                  return render json: {
                    error: "Validation error: All required MASS and FAST questions for behavior '#{bname}' must be answered before submitting."
                  }, status: :unprocessable_content
                end
              end
            end

            # Persist target behaviors
            saved_targets = []
            combined_scores = { sensory: 0, escape: 0, attention: 0, tangible: 0 }

            raw_targets.each do |tb|
              bname = tb[:behavior_name] || tb[:behaviorName] || tb[:name] || "Target Behavior"
              bta = @behavior_assessment.behavior_target_assessments.find_or_initialize_by(behavior_name: bname)
              bta.mass_responses = (tb[:massAnswers] || tb[:mass_responses] || {}).to_unsafe_h rescue (tb[:massAnswers] || tb[:mass_responses] || {})
              bta.fast_responses = (tb[:fastAnswers] || tb[:fast_responses] || {}).to_unsafe_h rescue (tb[:fastAnswers] || tb[:fast_responses] || {})
              bta.status = is_submitting ? "completed" : "draft"
              bta.completed_at = Time.current if is_submitting
              bta.calculate_function_scores!
              bta.save!

              saved_targets << {
                id: bta.id.to_s,
                behavior_name: bta.behavior_name,
                behaviorName: bta.behavior_name,
                mass_responses: bta.mass_responses,
                massAnswers: bta.mass_responses,
                fast_responses: bta.fast_responses,
                fastAnswers: bta.fast_responses,
                function_scores: bta.function_scores,
                scores: bta.function_scores,
                dominant_function: bta.dominant_function,
                hypothesized_function: bta.hypothesized_function,
                risk_indicators: bta.risk_indicators,
                status: bta.status
              }

              bta.function_scores.each do |fn, val|
                combined_scores[fn.to_sym] = (combined_scores[fn.to_sym] || 0) + val.to_i
              end
            end

            @behavior_assessment.status = is_submitting ? "completed" : "draft"
            @behavior_assessment.submitted_at = Time.current if is_submitting
            @behavior_assessment.save!

            # Sync legacy MassAssessment & FastAssessment records for spec compatibility
            first_target = raw_targets.first
            sync_legacy_assessments(first_target[:massAnswers] || first_target[:mass_responses],
                                    first_target[:fastAnswers] || first_target[:fast_responses],
                                    is_submitting)

            return render json: {
              status: "success",
              data: {
                student_id: @student.id,
                target_behaviors: saved_targets,
                targetBehaviors: saved_targets,
                massAnswers: saved_targets.first&.dig(:massAnswers) || {},
                fastAnswers: saved_targets.first&.dig(:fastAnswers) || {},
                records: params[:records] || [],
                scores: combined_scores,
                function_scores: combined_scores,
                dominant_function: combined_scores.max_by { |_, v| v }&.first&.to_s&.capitalize || "Sensory",
                hypothesized_function: combined_scores.max_by { |_, v| v }&.first&.to_s&.capitalize || "Sensory",
                risk_indicators: saved_targets.first&.dig(:risk_indicators) || {},
                status: @behavior_assessment.status
              }
            }
          end

          # Flat single-behavior payload support (legacy / fallback)
          mass_answers = params[:massAnswers] || params[:mass_responses]
          fast_answers = params[:fastAnswers] || params[:fast_responses]

          if is_submitting
            m_count = mass_answers.respond_to?(:keys) ? mass_answers.keys.count { |k| mass_answers[k].present? } : 0
            f_count = fast_answers.respond_to?(:keys) ? fast_answers.keys.count { |k| !fast_answers[k].nil? } : 0
            if m_count < 12 && f_count < 8 && (params[:records].blank? || params[:records].empty?)
              return render json: { error: "Validation error: All required questionnaire responses must be answered before submitting." }, status: :unprocessable_content
            end
          end

          # Sync with BehaviorAssessment and target record
          bta = @behavior_assessment.behavior_target_assessments.find_or_initialize_by(behavior_name: "General Behavior")
          bta.mass_responses = mass_answers.respond_to?(:to_unsafe_h) ? mass_answers.to_unsafe_h : (mass_answers || {})
          bta.fast_responses = fast_answers.respond_to?(:to_unsafe_h) ? fast_answers.to_unsafe_h : (fast_answers || {})
          bta.status = is_submitting ? "completed" : "draft"
          bta.completed_at = Time.current if is_submitting
          bta.calculate_function_scores!
          bta.save!

          @behavior_assessment.status = is_submitting ? "completed" : "draft"
          @behavior_assessment.submitted_at = Time.current if is_submitting
          @behavior_assessment.save!

          mass_assessment, fast_assessment = sync_legacy_assessments(mass_answers, fast_answers, is_submitting)

          mass_sc = mass_assessment.function_scores
          fast_sc = fast_assessment.function_scores

          combined_scores = {
            sensory: mass_sc[:sensory].to_i + fast_sc[:sensory].to_i,
            escape: mass_sc[:escape].to_i + fast_sc[:escape].to_i,
            attention: mass_sc[:attention].to_i + fast_sc[:attention].to_i,
            tangible: mass_sc[:tangible].to_i + fast_sc[:tangible].to_i
          }

          render json: {
            status: "success",
            data: {
              student_id: @student.id,
              target_behaviors: [
                {
                  id: bta.id.to_s,
                  behavior_name: bta.behavior_name,
                  behaviorName: bta.behavior_name,
                  mass_responses: bta.mass_responses,
                  massAnswers: bta.mass_responses,
                  fast_responses: bta.fast_responses,
                  fastAnswers: bta.fast_responses,
                  function_scores: bta.function_scores,
                  scores: bta.function_scores,
                  dominant_function: bta.dominant_function,
                  hypothesized_function: bta.hypothesized_function,
                  risk_indicators: bta.risk_indicators,
                  status: bta.status
                }
              ],
              massAnswers: mass_assessment.responses,
              fastAnswers: fast_assessment.responses,
              records: params[:records] || [],
              scores: combined_scores,
              function_scores: combined_scores,
              mass_scores: mass_sc,
              fast_scores: fast_sc,
              dominant_function: mass_assessment.dominant_function,
              hypothesized_function: fast_assessment.hypothesized_function,
              risk_indicators: fast_assessment.risk_indicators,
              status: @behavior_assessment.status
            }
          }
        end

        private

        def set_student
          @student = Student.find_by(id: params[:student_id])
          return render json: { error: "Student not found" }, status: :not_found unless @student

          @cycle = AssessmentCycle.kept.find_or_create_by!(student: @student, status: "in_progress") do |c|
            c.started_on = Date.current
          end
          @behavior_assessment = @cycle.behavior_assessment || @cycle.create_behavior_assessment!(status: "draft")
        end

        def sync_legacy_assessments(mass_answers, fast_answers, is_submitting)
          mass_assessment = MassAssessment.where(student_id: @student.id, status: "draft").order(created_at: :desc).first
          mass_assessment ||= MassAssessment.new(student: @student, teacher: current_user&.staff_member, status: "draft")

          if mass_answers.present?
            raw = mass_answers.respond_to?(:to_unsafe_h) ? mass_answers.to_unsafe_h : (mass_answers.is_a?(Hash) ? mass_answers : {})
            mass_assessment.responses = (mass_assessment.responses || {}).merge(raw)
            mass_assessment.calculate_scores!
          else
            mass_assessment.calculate_scores!
          end

          fast_assessment = FastAssessment.where(student_id: @student.id, status: "draft").order(created_at: :desc).first
          fast_assessment ||= FastAssessment.new(student: @student, teacher: current_user&.staff_member, status: "draft")

          if fast_answers.present?
            raw = fast_answers.respond_to?(:to_unsafe_h) ? fast_answers.to_unsafe_h : (fast_answers.is_a?(Hash) ? fast_answers : {})
            fast_assessment.responses = (fast_assessment.responses || {}).merge(raw)
            fast_assessment.calculate_risks!
          else
            fast_assessment.calculate_risks!
          end

          if is_submitting
            mass_assessment.status = "completed"
            mass_assessment.completed_at = Time.current
            fast_assessment.status = "completed"
            fast_assessment.completed_at = Time.current
          end

          mass_assessment.save!
          fast_assessment.save!

          [mass_assessment, fast_assessment]
        end
      end
    end
  end
end
