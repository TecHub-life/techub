class CreateBattles < ActiveRecord::Migration[8.0]
  def change
    create_table :battles do |t|
      t.integer :challenger_profile_id, null: false
      t.integer :opponent_profile_id, null: false
      t.integer :winner_profile_id
      t.integer :challenger_hp, default: 100
      t.integer :opponent_hp, default: 100
      t.string :status, default: "pending", null: false
      t.json :battle_log, default: []
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :battles, :challenger_profile_id
    add_index :battles, :opponent_profile_id
    add_index :battles, :winner_profile_id
    add_index :battles, :status
    add_index :battles, :created_at

    add_foreign_key :battles, :profiles, column: :challenger_profile_id
    add_foreign_key :battles, :profiles, column: :opponent_profile_id
    add_foreign_key :battles, :profiles, column: :winner_profile_id
  end
end
