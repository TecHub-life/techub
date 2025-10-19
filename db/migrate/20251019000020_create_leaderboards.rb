class CreateLeaderboards < ActiveRecord::Migration[8.0]
  def change
    create_table :leaderboards do |t|
      t.string :kind, null: false # followers_total, followers_gain_30d, stars_total, stars_gain_30d, repos_most_starred
      t.string :window, null: false, default: "30d" # 7d|30d|90d|all
      t.date :as_of, null: false
      t.json :entries, null: false, default: [] # [{ login:, value:, extra: {} }, ...]
      t.timestamps
    end
    add_index :leaderboards, [ :kind, :window, :as_of ], unique: true
  end
end
