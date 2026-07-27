class ApplicationSerializer
  def initialize(resource)
    @resource = resource
  end

  def as_json
    if @resource.respond_to?(:each)
      @resource.map { |record| serialize(record) }
    else
      serialize(@resource)
    end
  end

  private

  def serialize(_resource)
    raise NotImplementedError, "#{self.class}#serialize must be implemented"
  end
end
