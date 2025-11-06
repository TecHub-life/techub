class AddPreferredOgKindToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :preferred_og_kind, :string, default: "og", null: false
    add_index :profiles, :preferred_og_kind
  end
end
