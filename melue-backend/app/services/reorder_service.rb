class ReorderService < ApplicationService
  def initialize(model_class, ids)
    @model_class = model_class
    @ids = ids
  end

  def call
    validate_ids
    return failure(@errors.join(", ")) unless @errors.empty?

    ActiveRecord::Base.transaction do
      @ids.each_with_index do |id, index|
        record = @model_class.find(id)
        record.update!(display_order: index)
      end
    end

    success
  rescue ActiveRecord::RecordNotFound => e
    failure("Record not found: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    failure("Update failed: #{e.message}")
  end

  private

  def validate_ids
    @errors = []
    @errors << "IDs array cannot be empty" if @ids.blank?
    @errors << "All IDs must be integers or UUIDs" unless @ids.all? { |id| valid_id?(id) }
  end

  def valid_id?(id)
    return true if id.is_a?(Integer)
    return true if id.is_a?(String) && id.match?(/\A\d+\z/)
    return true if id.is_a?(String) && id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    false
  end
end
