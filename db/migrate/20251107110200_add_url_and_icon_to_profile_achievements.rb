class AddUrlAndIconToProfileAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :profile_achievements, :url, :string
    add_column :profile_achievements, :fa_icon, :string
  end
end
