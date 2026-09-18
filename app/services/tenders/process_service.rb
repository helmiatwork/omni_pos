module Tenders
  class ProcessService
    Result = Struct.new(:success, :tender, :error, keyword_init: true) do
      def success?
        !!success
      end
    end

    class << self
      def call(order:, method:, amount_cents:, idempotency_key:, customer_id: nil, pin: nil, wallet_client: nil)
        existing_tender = Tender.find_by(idempotency_key: idempotency_key)
        return Result.new(success: true, tender: existing_tender) if existing_tender

        raise Errors::TenderExceedsBalanceError, 'Payment exceeds remaining balance' if amount_cents.to_i > order.remaining_cents

        unless %w[created tendering].include?(order.status)
          raise Errors::InvalidStateTransitionError, "Cannot process payment for order in #{order.status} state"
        end

        reference_id = nil
        metadata = {}

        if method.to_s == 'wallet'
          client = wallet_client || OmniWalletClient.new
          merchant_id = order.metadata['merchant_id'] || ENV.fetch('POS_MERCHANT_ID', 'default-merchant')
          res = client.debit_wallet(
            customer_id: customer_id,
            merchant_id: merchant_id,
            amount_cents: amount_cents,
            pin: pin,
            idempotency_key: idempotency_key,
            order_id: order.id
          )

          res_hash = res.respond_to?(:with_indifferent_access) ? res.with_indifferent_access : res
          raise Errors::WalletClientError, (res_hash[:error] || 'Wallet debit failed') unless res_hash[:success]

          reference_id = res_hash[:transaction_id]
          metadata[:customer_id] = customer_id if customer_id
        end

        order.with_lock do
          existing = order.tenders.find_by(idempotency_key: idempotency_key)
          return Result.new(success: true, tender: existing) if existing

          order.reload
          unless %w[created tendering].include?(order.status)
            raise Errors::InvalidStateTransitionError, "Cannot process payment for order in #{order.status} state"
          end

          if amount_cents.to_i > order.remaining_cents
            raise Errors::TenderExceedsBalanceError, 'Payment exceeds remaining balance'
          end

          tender = order.tenders.create!(
            method: method,
            amount_cents: amount_cents,
            status: 'captured',
            idempotency_key: idempotency_key,
            reference_id: reference_id,
            metadata: metadata
          )

          order.reload
          if order.captured_tenders_total_cents >= order.total_cents
            order.update!(status: 'paid')
          else
            order.update!(status: 'tendering')
          end

          Result.new(success: true, tender: tender)
        end
      end
    end
  end
end
