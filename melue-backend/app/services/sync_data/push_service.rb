module SyncData
  class PushService < ApplicationService
    def initialize(payload)
      @payload = payload.deep_symbolize_keys
      @client_timestamp = @payload[:client_timestamp].present? ? Time.zone.parse(@payload[:client_timestamp]) : Time.current
      @time_offset = Time.current - @client_timestamp
    end

    def call
      ActiveRecord::Base.transaction do
        Array(@payload[:mutations]).each do |mutation|
          process_mutation(mutation)
        end
      end
      success({ server_timestamp: Time.current.iso8601 })
    rescue StandardError => e
      failure(e.message)
    end

    private

    def process_mutation(mutation)
      # Ensure model is allowed to be synced
      allowed_models = %w[Student Goal StudentGoal TherapySession Trial Iup PreferenceAssessment PreferenceObservation SessionParticipant]
      return unless allowed_models.include?(mutation[:type].to_s.classify)

      model_class = mutation[:type].to_s.classify.constantize
      operation = mutation[:operation].to_s
      data = mutation[:data] || {}

      # Time reconciliation for Trial logs
      if model_class == Trial && data[:logged_at].present?
        data[:logged_at] = (Time.zone.parse(data[:logged_at].to_s) + @time_offset).iso8601
      end

      case operation
      when "insert"
        model_class.create!(data)
      when "update"
        record = model_class.with_discarded.find_by(id: data[:id])
        return unless record

        if data[:base_updated_at].present?
          base_time = Time.zone.parse(data[:base_updated_at].to_s)
          # Conflict Resolution: Server Authoritative
          # Reject the update if the server record is newer than what client thought it was
          return if record.updated_at > base_time
        end

        data.delete(:base_updated_at)
        record.update!(data)
      when "delete"
        record = model_class.find_by(id: data[:id])
        record&.discard
      end
    end
  end
end
