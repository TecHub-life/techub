class AddLastSyncErrorToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :last_sync_error, :text
    add_column :profiles, :last_sync_error_at, :datetime
  end
end
