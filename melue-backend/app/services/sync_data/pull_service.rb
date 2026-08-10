module SyncData
  class PullService < ApplicationService
    def initialize(last_synced_at)
      @last_synced_at = last_synced_at.present? ? Time.zone.parse(last_synced_at) : Time.at(0)
    end

    def call
      data = {
        students: fetch(Student),
        goals: fetch(Goal),
        student_goals: fetch(StudentGoal),
        therapy_sessions: fetch(TherapySession),
        trials: fetch(Trial),
        iups: fetch(Iup),
        preference_assessments: fetch(PreferenceAssessment),
        preference_observations: fetch(PreferenceObservation),
        session_participants: fetch(SessionParticipant)
      }

      success({ server_timestamp: Time.current.iso8601, data: data })
    rescue StandardError => e
      failure(e.message)
    end

    private

    def fetch(model_class)
      model_class.with_discarded
                 .where("updated_at > ? OR discarded_at > ?", @last_synced_at, @last_synced_at)
                 .as_json
    end
  end
end
