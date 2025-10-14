class CreateProfilePipelineEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_pipeline_events do |t|
      t.integer :profile_id, null: false
      t.string :stage, null: false
      t.string :status, null: false
      t.integer :duration_ms
      t.string :message
      t.datetime :created_at, null: false
    end
    add_index :profile_pipeline_events, :profile_id
    add_index :profile_pipeline_events, :created_at
  end
end
