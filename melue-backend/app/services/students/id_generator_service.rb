# frozen_string_literal: true

require "zlib"

module Students
  # Generates sequential, human-readable student identifiers in the format:
  #   MEL/{SEQUENCE}/{YY} (e.g., MEL/0001/25, MEL/0002/26)
  #
  # Enforces thread/process safety via PostgreSQL transaction-level advisory locks.
  class IdGeneratorService
    PREFIX = "MEL"

    class << self
      # Generates the next sequential student ID for the given enrollment year.
      #
      # @param enrolled_at [Time, Date, nil] the date/time of enrollment
      # @return [String] formatted ID (e.g., "MEL/0001/25")
      def generate(enrolled_at: Time.current)
        year_suffix = (enrolled_at.presence || Time.current).to_date.strftime("%y")
        lock_key = Zlib.crc32("STUDENT_ID_GENERATOR_#{PREFIX}_#{year_suffix}") & 0x7FFFFFFF

        Student.transaction do
          # Acquire transaction-level advisory lock to prevent race conditions during sequence allocation
          Student.connection.execute(
            Student.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(?)", lock_key ])
          )

          pattern = "#{PREFIX}-%-#{year_suffix}"
          existing_numbers = Student.unscoped
                                    .where("student_id LIKE ?", pattern)
                                    .pluck(:student_id)
                                    .map do |sid|
                                      parts = sid.to_s.split("-")
                                      parts.length == 3 ? parts[1].to_i : 0
                                    end

          next_number = (existing_numbers.max || 0) + 1
          formatted_sequence = next_number.to_s.rjust(4, "0")

          "#{PREFIX}-#{formatted_sequence}-#{year_suffix}"
        end
      end
    end
  end
end
