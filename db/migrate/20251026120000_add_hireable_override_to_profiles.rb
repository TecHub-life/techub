class AddHireableOverrideToProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :profiles, :hireable_override, :boolean
    add_index :profiles, :hireable_override
  end
end
