class ServiceResult
  attr_reader :data, :error, :status

  def initialize(success:, data: nil, error: nil, status: nil)
    @success = success
    @data = data
    @error = error
    @status = status
  end

  def self.success(data = nil)
    new(success: true, data: data)
  end

  # `status` is an optional HTTP status hint (e.g. :forbidden, :not_found)
  # that controllers may use instead of pattern-matching the error message.
  def self.failure(error = nil, status = nil)
    new(success: false, error: error, status: status)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end
