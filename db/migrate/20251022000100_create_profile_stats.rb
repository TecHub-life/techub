class CreateProfileStats < ActiveRecord::Migration[7.1]
  def change
    create_table :profile_stats do |t|
      t.references :profile, null: false, foreign_key: true
      t.date :stat_date, null: false
      t.integer :followers, null: false, default: 0
      t.integer :following, null: false, default: 0
      t.integer :public_repos, null: false, default: 0
      t.integer :total_stars, null: false, default: 0
      t.integer :total_forks, null: false, default: 0
      t.integer :repo_count, null: false, default: 0
      t.datetime :captured_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :profile_stats, [ :profile_id, :stat_date ], unique: true
  end
end
