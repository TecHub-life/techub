class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles do |t|
      t.string :github_login, null: false
      t.string :name
      t.string :avatar_url
      t.text :summary
      t.json :data, null: false, default: {}
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :profiles, :github_login, unique: true
  end
end
