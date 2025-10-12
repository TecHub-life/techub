class AddPipelineStatusToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :submitted_at, :datetime
    add_column :profiles, :last_pipeline_status, :string
    add_column :profiles, :last_pipeline_error, :text
  end
end
