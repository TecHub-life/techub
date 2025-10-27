class AddMissingForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # Active Storage foreign keys
    add_foreign_key :active_storage_attachments, :active_storage_blobs, column: :blob_id
    add_foreign_key :active_storage_variant_records, :active_storage_blobs, column: :blob_id

    # Profile pipeline events foreign key
    add_foreign_key :profile_pipeline_events, :profiles
  end
end
