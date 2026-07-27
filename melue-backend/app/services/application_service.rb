class ApplicationService
  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError, "#{self.class}#call must be implemented"
  end

  private

  def success(data = nil)
    ServiceResult.success(data)
  end

  def failure(error = nil)
    ServiceResult.failure(error)
  end
end
