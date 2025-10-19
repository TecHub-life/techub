class AddAiArtOptInToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :ai_art_opt_in, :boolean, default: false, null: false
    add_index :profiles, :ai_art_opt_in
  end
end
