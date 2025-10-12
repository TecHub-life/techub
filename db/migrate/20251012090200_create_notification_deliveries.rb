class CreateNotificationDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_deliveries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :notification_deliveries, [ :user_id, :event, :subject_type, :subject_id ], unique: true, name: "idx_delivery_uniqueness"
  end
end
