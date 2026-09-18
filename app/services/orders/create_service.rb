module Orders
  class CreateService
    Result = Struct.new(:success, :order, :error, keyword_init: true) do
      def success?
        !!success
      end
    end

    class << self
      def call(station_ref:, vertical:, lines:, metadata: {})
        return Result.new(success: false, error: 'Order must contain at least one line item') if lines.blank?

        Order.transaction do
          order = Order.new(
            station_ref: station_ref,
            vertical: vertical,
            status: 'created',
            metadata: metadata || {}
          )

          total = 0
          (lines || []).each do |line_data|
            data = line_data.is_a?(Hash) ? line_data.with_indifferent_access : line_data
            qty = data[:qty] || 1
            unit_price_cents = data[:unit_price_cents].to_i
            line_total = (qty.to_d * unit_price_cents).round

            order.order_lines.build(
              name: data[:name],
              sku: data[:sku],
              qty: qty,
              unit: data[:unit] || 'item',
              unit_price_cents: unit_price_cents,
              total_cents: line_total,
              modifiers: data[:modifiers] || {}
            )
            total += line_total
          end

          order.total_cents = total
          order.save!

          Result.new(success: true, order: order)
        end
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success: false, error: e.message)
      end
    end
  end
end
