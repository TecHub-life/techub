class AddLastAiRegeneratedAtToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :last_ai_regenerated_at, :datetime
    add_index :profiles, :last_ai_regenerated_at
  end
end
