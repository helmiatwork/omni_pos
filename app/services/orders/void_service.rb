module Orders
  class VoidService
    Result = Struct.new(:success, :order, keyword_init: true) do
      def success?
        !!success
      end
    end

    class << self
      def call(order:, reason:, actor_id:)
        order.with_lock do
          if %w[fulfilled voided].include?(order.status)
            raise Errors::InvalidStateTransitionError, "Cannot void #{order.status} order"
          end

          if order.captured_tenders_total_cents.positive?
            raise Errors::InvalidStateTransitionError, 'Cannot void order with captured tenders; issue refund instead'
          end

          order.update!(status: 'voided')

          PosAuditEvent.create!(
            actor_id: actor_id,
            event_name: 'void',
            payload: { order_id: order.id, reason: reason }
          )

          Result.new(success: true, order: order)
        end
      end
    end
  end
end
