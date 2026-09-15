class CreateWebhookIdempotencyRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_idempotency_records do |t|
      t.string :provider, null: false
      t.string :external_id, null: false
      t.string :webhook_hash, null: false
      t.boolean :processed, default: false, null: false
      t.datetime :processed_at, null: true

      t.timestamps
    end

    add_index :webhook_idempotency_records, [:provider, :external_id], unique: true
    add_index :webhook_idempotency_records, :webhook_hash, unique: true
    add_index :webhook_idempotency_records, :processed
  end
end
