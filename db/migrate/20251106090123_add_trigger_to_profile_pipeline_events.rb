class AddTriggerToProfilePipelineEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :profile_pipeline_events, :trigger, :string
    add_index :profile_pipeline_events, :trigger
  end
end
