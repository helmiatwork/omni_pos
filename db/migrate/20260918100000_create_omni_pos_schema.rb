class CreateOmniPosSchema < ActiveRecord::Migration[8.0]
  def up
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # 1. Staff
    create_table :staff, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :role, null: false, default: 'cashier'
      t.string :pin_hash, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :staff, :role

    # 2. Shifts
    create_table :shifts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :device_id, null: false
      t.uuid :cashier_id, null: false
      t.bigint :opening_cash, null: false, default: 0
      t.timestamptz :opened_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :closed_at
      t.bigint :counted_cash
      t.bigint :expected_cash
      t.bigint :variance
      t.timestamps
    end
    add_foreign_key :shifts, :staff, column: :cashier_id
    add_index :shifts, :device_id
    add_index :shifts, :cashier_id
    add_index :shifts, :closed_at

    # 3. Drawer Events
    create_table :drawer_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :shift_id, null: false
      t.string :event_type, null: false # safe_drop | paid_in | paid_out
      t.bigint :amount, null: false
      t.uuid :authorized_by
      t.timestamptz :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
    add_foreign_key :drawer_events, :shifts, column: :shift_id
    add_foreign_key :drawer_events, :staff, column: :authorized_by
    add_index :drawer_events, :shift_id
    add_index :drawer_events, :event_type

    # 4. Orders
    create_table :orders, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :station_ref, null: false
      t.string :vertical, null: false # grocery | food | carwash
      t.string :status, null: false, default: 'created' # created | tendering | paid | fulfilling | fulfilled | voided | refunded
      t.bigint :total_cents, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :orders, :station_ref
    add_index :orders, :vertical
    add_index :orders, :status

    # 5. Order Lines
    create_table :order_lines, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :order_id, null: false
      t.string :name, null: false
      t.string :sku
      t.decimal :qty, precision: 12, scale: 3, null: false, default: 1.000
      t.string :unit, null: false, default: 'item'
      t.bigint :unit_price_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.jsonb :modifiers, null: false, default: {}
      t.timestamps
    end
    add_foreign_key :order_lines, :orders, column: :order_id, on_delete: :cascade
    add_index :order_lines, :order_id

    # 6. Tenders
    create_table :tenders, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :order_id, null: false
      t.string :method, null: false # wallet | cash | qris
      t.bigint :amount_cents, null: false
      t.string :status, null: false, default: 'pending' # pending | captured | reversed
      t.string :idempotency_key, null: false
      t.string :reference_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_foreign_key :tenders, :orders, column: :order_id
    add_index :tenders, :order_id
    add_index :tenders, :idempotency_key, unique: true
    add_index :tenders, :status

    # 7. POS Audit Events
    create_table :pos_audit_events do |t|
      t.uuid :actor_id, null: false
      t.string :event_name, null: false # void | refund | price_override | no_sale_open | shift_close
      t.jsonb :payload, null: false, default: {}
      t.timestamptz :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
    add_index :pos_audit_events, :actor_id
    add_index :pos_audit_events, :event_name

    # Trigger anti-UPDATE / anti-DELETE on pos_audit_events
    execute <<-SQL
      CREATE OR REPLACE FUNCTION trg_forbid_pos_audit_events_mutation()
      RETURNS TRIGGER AS $$
      BEGIN
        RAISE EXCEPTION 'pos_audit_events is an append-only forensic log: % is strictly forbidden', TG_OP;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER trg_pos_audit_events_immutable
      BEFORE UPDATE OR DELETE ON pos_audit_events
      FOR EACH ROW
      EXECUTE FUNCTION trg_forbid_pos_audit_events_mutation();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS trg_pos_audit_events_immutable ON pos_audit_events;
      DROP FUNCTION IF EXISTS trg_forbid_pos_audit_events_mutation();
    SQL

    drop_table :pos_audit_events, if_exists: true
    drop_table :tenders, if_exists: true
    drop_table :order_lines, if_exists: true
    drop_table :orders, if_exists: true
    drop_table :drawer_events, if_exists: true
    drop_table :shifts, if_exists: true
    drop_table :staff, if_exists: true
  end
end
