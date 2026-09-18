require 'rails_helper'

RSpec.describe Staff, type: :model do
  describe 'validations and PIN hashing' do
    it 'creates a valid staff member and hashes the PIN' do
      staff = described_class.new(name: 'Ahmad', role: 'cashier', pin: '654321')
      expect(staff).to be_valid
      expect(staff.save).to be true
      expect(staff.pin_hash).to be_present
      expect(staff.pin_hash).not_to eq('654321')
    end

    it 'authenticates correct PIN and rejects incorrect PIN' do
      staff = create(:staff, pin: '123456')
      expect(staff.authenticate_pin('123456')).to be true
      expect(staff.authenticate_pin('000000')).to be false
    end

    it 'validates role presence and inclusion' do
      expect(build(:staff, role: 'invalid_role')).not_to be_valid
      expect(build(:staff, role: 'supervisor')).to be_valid
    end

    it 'validates name presence' do
      expect(build(:staff, name: '')).not_to be_valid
    end

    it 'handles corrupted pin_hash gracefully' do
      staff = build(:staff)
      staff.pin_hash = 'not-a-valid-bcrypt-hash'
      expect(staff.authenticate_pin('123456')).to be false
    end
  end
end
