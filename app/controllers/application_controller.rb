class ApplicationController < ActionController::Base
  include InertiaRails::Controller

  protect_from_forgery with: :exception, unless: -> { request.format.json? && !request.headers['X-Inertia'].present? }

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def json_request?
    return false if request.headers['X-Inertia'].present?
    request.format.json? || (request.headers['Accept'].to_s.include?('application/json') && !request.headers['Accept'].to_s.include?('text/html'))
  end

  def record_not_found(error)
    if json_request?
      render json: { success: false, error: error.message }, status: :not_found
    else
      redirect_back fallback_location: root_path, alert: error.message
    end
  end

  def current_actor_id
    session[:staff_id] || default_staff&.id
  end

  def default_staff
    Staff.first
  end
end
