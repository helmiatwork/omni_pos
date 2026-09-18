class PadController < ApplicationController
  def show
    station_ref = params[:station_ref].presence || 'Station-01'
    order = Order.includes(:order_lines, :tenders)
                 .where(station_ref: station_ref, status: %w[created tendering])
                 .order(created_at: :desc)
                 .first

    payload = {
      order: order&.as_json(include: [:order_lines, :tenders]),
      station_ref: station_ref
    }

    respond_to do |format|
      format.html { render inertia: 'Pad', props: payload }
      format.json { render json: payload }
    end
  end
end
