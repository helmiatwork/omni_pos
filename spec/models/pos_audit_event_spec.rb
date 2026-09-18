require 'rails_helper'

RSpec.describe PosAuditEvent, type: :model do
  describe 'immutability database trigger' do
    it 'creates forensic audit event successfully' do
      event = described_class.create!(
        actor_id: SecureRandom.uuid,
        event_name: 'void',
        payload: { order_id: SecureRandom.uuid, reason: 'Wrong table' }
      )

      expect(event).to be_persisted
    end

    it 'raises ReadOnlyRecord on Rails update or destroy' do
      event = described_class.create!(
        actor_id: SecureRandom.uuid,
        event_name: 'safe_drop',
        payload: { amount: 100_000 }
      )

      expect {
        event.update!(event_name: 'tampered')
      }.to raise_error(ActiveRecord::ReadOnlyRecord)

      expect {
        event.destroy!
      }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'strictly forbids direct SQL UPDATE via PostgreSQL trigger' do
      event = described_class.create!(
        actor_id: SecureRandom.uuid,
        event_name: 'safe_drop',
        payload: { amount: 100_000 }
      )

      expect {
        ActiveRecord::Base.connection.execute(
          "UPDATE pos_audit_events SET event_name = 'tampered' WHERE id = #{event.id}"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /append-only forensic log/i)
    end

    it 'strictly forbids direct SQL DELETE via PostgreSQL trigger' do
      event = described_class.create!(
        actor_id: SecureRandom.uuid,
        event_name: 'price_override',
        payload: { line_id: SecureRandom.uuid }
      )

      expect {
        ActiveRecord::Base.connection.execute(
          "DELETE FROM pos_audit_events WHERE id = #{event.id}"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /append-only forensic log/i)
    end
  end
end
