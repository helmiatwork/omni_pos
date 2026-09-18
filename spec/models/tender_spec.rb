require 'rails_helper'

RSpec.describe Tender, type: :model do
  let(:order) { create(:order, total_cents: 100_000) }

  describe 'validations and methods' do
    it 'creates a valid captured tender' do
      tender = described_class.create!(
        order: order,
        method: 'wallet',
        amount_cents: 100_000,
        status: 'captured',
        idempotency_key: SecureRandom.uuid,
        reference_id: 'REF-123'
      )

      expect(tender).to be_persisted
      expect(tender.captured?).to be true
      expect(tender.amount_money).to eq(Money.new(100_000, 'IDR'))
    end

    it 'validates method inclusion' do
      expect(build(:tender, method: 'bitcoin')).not_to be_valid
      expect(build(:tender, method: 'wallet')).to be_valid
      expect(build(:tender, method: 'cash')).to be_valid
      expect(build(:tender, method: 'qris')).to be_valid
    end

    it 'enforces unique idempotency_key' do
      key = SecureRandom.uuid
      create(:tender, idempotency_key: key)
      expect {
        create(:tender, idempotency_key: key)
      }.to raise_error(ActiveRecord::RecordInvalid, /already been taken/i)

      duplicate_tender = build(:tender, idempotency_key: key)
      expect {
        duplicate_tender.save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
