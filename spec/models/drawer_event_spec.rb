require 'rails_helper'

RSpec.describe DrawerEvent, type: :model do
  let(:shift) { create(:shift) }
  let(:supervisor) { create(:staff, role: 'supervisor') }

  describe 'validations' do
    it 'creates valid drawer event' do
      event = described_class.create!(
        shift: shift,
        event_type: 'safe_drop',
        amount: 500_000,
        authorized_staff: supervisor
      )

      expect(event).to be_persisted
      expect(event.amount).to eq(500_000)
      expect(event.amount_money).to eq(Money.new(500_000, 'IDR'))
    end

    it 'validates event_type inclusion' do
      expect(build(:drawer_event, event_type: 'invalid')).not_to be_valid
      expect(build(:drawer_event, event_type: 'paid_in')).to be_valid
      expect(build(:drawer_event, event_type: 'paid_out')).to be_valid
      expect(build(:drawer_event, event_type: 'safe_drop')).to be_valid
    end

    it 'rejects negative amount' do
      expect(build(:drawer_event, amount: -100)).not_to be_valid
    end
  end
end
