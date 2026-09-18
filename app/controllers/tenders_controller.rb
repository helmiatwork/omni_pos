class TendersController < ApplicationController
  def create
    order = Order.find(params[:id])
    p = tender_params

    result = Tenders::ProcessService.call(
      order: order,
      method: p[:method],
      amount_cents: p[:amount_cents],
      idempotency_key: p[:idempotency_key],
      customer_id: p[:customer_id],
      pin: p[:pin]
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
  rescue Errors::TenderExceedsBalanceError,
         Errors::InvalidStateTransitionError,
         Errors::WalletClientError,
         ActiveRecord::RecordInvalid => e
    if json_request?
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    else
      redirect_back fallback_location: sell_path, alert: e.message
    end
  end

  private

  def tender_params
    params.permit(:method, :amount_cents, :idempotency_key, :customer_id, :pin)
  end
end
