class AddListingStateToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :listed, :boolean, default: true, null: false
    add_column :profiles, :unlisted_at, :datetime

    add_index :profiles, :listed
    add_index :profiles, :unlisted_at
  end
end
