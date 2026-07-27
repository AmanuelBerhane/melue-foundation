class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,         with: :not_found
  rescue_from ActiveRecord::RecordInvalid,          with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing,   with: :bad_request
  rescue_from StandardError,                        with: :internal_server_error

  private

  def not_found(exception)
    render_error(exception.message, :not_found)
  end

  def unprocessable_entity(exception)
    render_error(exception.record.errors.full_messages, :unprocessable_entity)
  end

  def bad_request(exception)
    render_error(exception.message, :bad_request)
  end

  def internal_server_error(exception)
    raise exception if Rails.env.development? || Rails.env.test?

    render_error("An unexpected error occurred", :internal_server_error)
  end

  def render_error(message, status)
    render json: { error: message }, status: status
  end
end
