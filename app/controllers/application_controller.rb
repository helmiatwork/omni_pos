class ApplicationController < ActionController::Base
  include InertiaRails::Controller

  protect_from_forgery with: :null_session, if: -> { request.format.json? || Rails.env.test? || request.headers['X-Inertia'].present? }

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def json_request?
    request.format.json? || request.content_type.to_s.include?('json') || request.headers['Accept'].to_s.include?('application/json')
  end

  def record_not_found(error)
    if json_request?
      render json: { success: false, error: error.message }, status: :not_found
    else
      redirect_back fallback_location: root_path, alert: error.message
    end
  end

  def current_actor_id
    params[:actor_id].presence || default_staff.id
  end

  def default_staff
    Staff.first || Staff.create!(
      name: 'Kasir Utama',
      role: 'cashier',
      pin_hash: BCrypt::Password.create('123456')
    )
  end
end
