class ShiftsController < ApplicationController
  def index
    current_shift = Shift.open.order(opened_at: :desc).first
    past_shifts = Shift.closed.includes(:cashier).order(closed_at: :desc).limit(20)
    audit_logs = PosAuditEvent.order(created_at: :desc).limit(30)

    payload = {
      current_shift: current_shift&.as_json(include: :cashier),
      past_shifts: past_shifts.as_json(include: :cashier),
      audit_logs: audit_logs.as_json
    }

    respond_to do |format|
      format.html { render inertia: 'Shift', props: payload }
      format.json { render json: payload }
    end
  end

  def open
    cashier_id = current_actor_id
    device_id = shift_open_params[:device_id].presence || SecureRandom.uuid
    opening_cash = shift_open_params[:opening_cash]

    shift = Shift.new(
      cashier_id: cashier_id,
      device_id: device_id,
      opening_cash: opening_cash,
      opened_at: Time.current
    )

    if shift.save
      if json_request?
        render json: { success: true, shift: shift.as_json(include: :cashier) }, status: :created
      else
        redirect_to shifts_path, notice: 'Shift opened successfully'
      end
    else
      if json_request?
        render json: { success: false, errors: shift.errors.full_messages }, status: :unprocessable_entity
      else
        redirect_to shifts_path, alert: shift.errors.full_messages.join(', ')
      end
    end
  end

  def close
    shift = Shift.find(params[:id])
    actor_id = current_actor_id

    result = Shifts::CloseService.call(
      shift: shift,
      counted_cash: shift_close_params[:counted_cash],
      actor_id: actor_id
    )

    if json_request?
      render json: {
        success: true,
        shift: result.shift.as_json(include: :cashier),
        variance: result.variance
      }, status: :ok
    else
      redirect_to shifts_path, notice: "Shift closed. Cash variance: #{result.variance}"
    end
  rescue Errors::ShiftAlreadyClosedError, Errors::InvalidStateTransitionError => e
    if json_request?
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    else
      redirect_to shifts_path, alert: e.message
    end
  end

  private

  def shift_open_params
    params.permit(:device_id, :opening_cash)
  end

  def shift_close_params
    params.permit(:counted_cash)
  end
end
