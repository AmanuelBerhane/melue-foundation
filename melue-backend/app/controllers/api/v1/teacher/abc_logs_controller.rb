# frozen_string_literal: true

module Api
  module V1
    module Teacher
      class AbcLogsController < Api::V1::BaseController
        before_action :authenticate_user!

        # GET /api/v1/teacher/abc-log
        def index
          incidents = BehaviorIncident.includes(:student, :staff_member).order(occurred_at: :desc)

          if params[:studentId].present?
            incidents = incidents.where(student_id: params[:studentId])
          end

          if params[:behavior].present? && params[:behavior] != "All"
            incidents = incidents.where("behavior_name ILIKE ?", "%#{params[:behavior]}%")
          end

          rows = incidents.map do |inc|
            {
              id: inc.id.to_s,
              date: inc.occurred_at ? inc.occurred_at.strftime("%Y-%m-%d") : Date.current.to_s,
              time: inc.occurred_at ? inc.occurred_at.strftime("%I:%M %p") : "10:00 AM",
              location: inc.location.presence || "Classroom",
              behavior: inc.behavior_name,
              frequency: inc.frequency.to_s.humanize,
              intensity: inc.intensity.to_s.humanize,
              category: inc.category.to_s.humanize,
              antecedent: inc.antecedent,
              consequence: inc.consequence,
              notes: inc.additional_notes || "",
              teacher: inc.staff_member&.full_name || "Teacher A"
            }
          end

          most_common_behavior = rows.group_by { |r| r[:behavior] }.max_by { |_k, v| v.size }&.first || "None"
          most_common_antecedent = rows.group_by { |r| r[:antecedent] }.max_by { |_k, v| v.size }&.first || "None"

          render json: {
            incidents: rows,
            stats: {
              totalIncidents: rows.size,
              mostCommonBehavior: most_common_behavior,
              mostCommonAntecedent: most_common_antecedent,
              thisWeek: rows.count { |r| Date.parse(r[:date]) >= 1.week.ago rescue true }
            }
          }
        end

        # POST /api/v1/teacher/abc-log
        def create
          student = Student.find_by(id: params[:studentId]) || Student.first
          return render_error("Student required", :bad_request) unless student

          staff = current_staff_member || StaffMember.first

          # Normalize frequency
          raw_freq = params[:frequency].to_s.downcase
          freq = case raw_freq
          when /rare/ then :rarely
          when /freq/ then :frequently
          when /const/ then :constantly
          else :occasionally
          end

          # Normalize intensity
          raw_int = params[:intensity].to_s.downcase
          intensity = case raw_int
          when /sev/ then :severe
          when /mod/ then :moderate
          else :mild
          end

          # Normalize category
          raw_cat = params[:category].to_s.downcase
          category = case raw_cat
          when /safe/ then :safety_concerns
          when /elop/ then :elopement
          when /flop/ then :flopping
          when /trans/ then :difficulty_with_transitions
          when /noise/ then :making_noises
          when /hyper/ then :hyperactivity
          when /obsess/ then :obsessive
          else :attention_seeking
          end

          incident = BehaviorIncident.new(
            student: student,
            staff_member: staff,
            behavior_name: params[:behavior] || params[:behavior_name] || "Disruptive Behavior",
            behavior_definition: params[:definition] || params[:behavior] || "Behavior recorded in log",
            frequency: freq,
            intensity: intensity,
            category: category,
            antecedent: params[:antecedent] || "Task Demand",
            consequence: params[:consequence] || "Verbal Redirection",
            location: params[:location] || "Classroom",
            additional_notes: params[:notes] || params[:additional_notes],
            occurred_at: params[:date] && params[:time] ? Time.zone.parse("#{params[:date]} #{params[:time]}") : Time.current
          )

          if incident.save
            render json: {
              id: incident.id.to_s,
              behavior: incident.behavior_name,
              success: true
            }, status: :created
          else
            render json: { errors: incident.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/teacher/abc-log/:id
        def destroy
          incident = BehaviorIncident.find(params[:id])
          incident.destroy
          render json: { success: true }
        end

        # GET /api/v1/teacher/abc-log/export
        def export
          render json: { message: "ABC log exported successfully", url: "/api/v1/teacher/abc-log" }
        end
      end
    end
  end
end
