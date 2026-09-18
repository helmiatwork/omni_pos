class TendersController < ApplicationController
  def create
    order = Order.find(params[:id])

    result = Tenders::ProcessService.call(
      order: order,
      method: params[:method],
      amount_cents: params[:amount_cents],
      idempotency_key: params[:idempotency_key],
      customer_id: params[:customer_id],
      pin: params[:pin]
    )

    if json_request?
      render json: {
        success: true,
        tender: result.tender.as_json,
        order: order.reload.as_json(include: [:order_lines, :tenders])
      }, status: :created
    else
      redirect_to sell_path, notice: 'Payment processed successfully'
    end
  rescue Errors::TenderExceedsBalanceError, Errors::InvalidStateTransitionError, Errors::WalletClientError => e
    if json_request?
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    else
      redirect_back fallback_location: sell_path, alert: e.message
    end
  end
end
