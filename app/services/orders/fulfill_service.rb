module Orders
  class FulfillService
    Result = Struct.new(:success, :order, keyword_init: true) do
      def success?
        !!success
      end
    end

    class << self
      def call(order:)
        if %w[voided refunded fulfilled].include?(order.status)
          raise Errors::InvalidStateTransitionError, "Cannot fulfill order in #{order.status} state"
        end

        if order.vertical == 'carwash' && !order.paid?
          raise Errors::PayFirstViolationError, 'Carwash orders must be paid before fulfilling'
        end

        order.status = 'fulfilling'
        if order.vertical == 'carwash'
          order.metadata ||= {}
          bay_ref = order.station_ref.presence || 'Bay-01'
          bay_ref = "#{bay_ref}-Queue" unless bay_ref.end_with?('-Queue')
          order.metadata['bay_queue'] = bay_ref
        end
        order.save!

        Result.new(success: true, order: order)
      end

      def complete(order:)
        unless order.status == 'fulfilling'
          raise Errors::InvalidStateTransitionError, "Cannot complete order in #{order.status} state"
        end

        order.update!(status: 'fulfilled')
        Result.new(success: true, order: order)
      end
    end
  end
end
