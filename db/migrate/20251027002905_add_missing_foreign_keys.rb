class AddMissingForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # Add foreign key for active_storage_attachments -> active_storage_blobs
    add_foreign_key :active_storage_attachments, :active_storage_blobs, column: :blob_id

    # Add foreign key for active_storage_variant_records -> active_storage_blobs
    add_foreign_key :active_storage_variant_records, :active_storage_blobs, column: :blob_id

    # Add foreign key for profile_pipeline_events -> profiles
    add_foreign_key :profile_pipeline_events, :profiles
  end
end
