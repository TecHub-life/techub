class CreateProfileOwnerships < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_ownerships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :profile, null: false, foreign_key: true
      t.timestamps
    end
    add_index :profile_ownerships, [ :user_id, :profile_id ], unique: true
  end
end
