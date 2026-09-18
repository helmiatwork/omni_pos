module Shifts
  class CloseService
    Result = Struct.new(:success, :shift, :variance, keyword_init: true) do
      def success?
        !!success
      end
    end

    class << self
      def call(shift:, counted_cash:, actor_id:)
        raise Errors::ShiftAlreadyClosedError, 'Shift is already closed' if shift.closed?

        Shift.transaction do
          shift.lock!

          # Pure blind close calculation:
          # Cash captured during shift
          cash_tenders = Tender.where(method: 'cash', status: 'captured')
                               .where('created_at >= ?', shift.opened_at)
                               .sum(:amount_cents)

          paid_in = shift.drawer_events.where(event_type: 'paid_in').sum(:amount)
          paid_out = shift.drawer_events.where(event_type: 'paid_out').sum(:amount)
          safe_drop = shift.drawer_events.where(event_type: 'safe_drop').sum(:amount)

          expected_cash = shift.opening_cash + cash_tenders + paid_in - paid_out - safe_drop
          counted = counted_cash.to_i
          variance = counted - expected_cash

          shift.update!(
            counted_cash: counted,
            expected_cash: expected_cash,
            variance: variance,
            closed_at: Time.current
          )

          PosAuditEvent.create!(
            actor_id: actor_id,
            event_name: 'shift_close',
            payload: {
              shift_id: shift.id,
              opening_cash: shift.opening_cash,
              cash_tenders: cash_tenders,
              paid_in: paid_in,
              paid_out: paid_out,
              safe_drop: safe_drop,
              counted_cash: counted,
              expected_cash: expected_cash,
              variance: variance
            }
          )

          Result.new(success: true, shift: shift, variance: variance)
        end
      end
    end
  end
end
