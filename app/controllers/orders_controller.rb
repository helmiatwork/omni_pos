class OrdersController < ApplicationController
  before_action :set_order, only: %i[fulfill complete void]

  def index
    scope = Order.includes(:order_lines, :tenders).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(station_ref: params[:station_ref]) if params[:station_ref].present?
    scope = scope.where(vertical: params[:vertical]) if params[:vertical].present?

    orders = scope.limit(50)
    filters = {
      status: params[:status],
      station_ref: params[:station_ref],
      vertical: params[:vertical]
    }

    payload = {
      orders: orders.as_json(include: [:order_lines, :tenders]),
      filters: filters
    }

    respond_to do |format|
      format.html { render inertia: 'Orders', props: payload }
      format.json { render json: payload }
    end
  end

  def create
    p = order_create_params
    station_ref = p[:station_ref].presence || 'Station-01'
    vertical = p[:vertical]
    lines = p[:lines]&.map(&:to_h) || []
    metadata = p[:metadata]&.to_h || {}

    result = Orders::CreateService.call(
      station_ref: station_ref,
      vertical: vertical,
      lines: lines,
      metadata: metadata
    )

    if json_request?
      if result.success?
        render json: { success: true, order: result.order.as_json(include: [:order_lines, :tenders]) }, status: :created
      else
        render json: { success: false, error: result.error }, status: :unprocessable_entity
      end
    else
      if result.success?
        redirect_to sell_path, notice: 'Order created successfully'
      else
        redirect_back fallback_location: sell_path, alert: result.error
      end
    end
  end

  def fulfill
    result = Orders::FulfillService.call(order: @order)

    if json_request?
      render json: { success: true, order: result.order.as_json(include: [:order_lines, :tenders]) }, status: :ok
    else
      redirect_back fallback_location: orders_path, notice: 'Order is now fulfilling'
    end
  rescue Errors::InvalidStateTransitionError, Errors::PayFirstViolationError => e
    if json_request?
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    else
      redirect_back fallback_location: orders_path, alert: e.message
    end
  end

  def complete
    result = Orders::FulfillService.complete(order: @order)

    if json_request?
      render json: { success: true, order: result.order.as_json(include: [:order_lines, :tenders]) }, status: :ok
    else
      redirect_back fallback_location: orders_path, notice: 'Order fulfilled'
    end
  rescue Errors::InvalidStateTransitionError => e
    if json_request?
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    else
      redirect_back fallback_location: orders_path, alert: e.message
    end
  end

  def void
    reason = void_params[:reason].presence || 'Voided by operator'
    actor_id = current_actor_id

    result = Orders::VoidService.call(order: @order, reason: reason, actor_id: actor_id)

    if json_request?
      render json: { success: true, order: result.order.as_json(include: [:order_lines, :tenders]) }, status: :ok
    else
      redirect_back fallback_location: orders_path, notice: 'Order voided'
    end
  rescue Errors::InvalidStateTransitionError => e
    if json_request?
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    else
      redirect_back fallback_location: orders_path, alert: e.message
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_create_params
    params.permit(
      :station_ref,
      :vertical,
      metadata: {},
      lines: [
        :name,
        :sku,
        :qty,
        :unit,
        :unit_price_cents,
        { modifiers: {} }
      ]
    )
  end

  def void_params
    params.permit(:reason)
  end
end
