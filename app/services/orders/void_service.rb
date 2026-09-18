module Orders
  class VoidService
    Result = Struct.new(:success, :order, keyword_init: true) do
      def success?
        !!success
      end
    end

    class << self
      def call(order:, reason:, actor_id:)
        if order.status == 'fulfilled'
          raise Errors::InvalidStateTransitionError, 'Cannot void fulfilled order'
        end

        Order.transaction do
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
