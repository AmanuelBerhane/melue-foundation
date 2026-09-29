# frozen_string_literal: true

# Serializer for Student Progress Monitoring (FR-134)
class StudentProgressMonitoringSerializer
  def initialize(data)
    @data = data
  end

  def as_json(*_args)
    @data
  end
end
