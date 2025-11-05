class AddContributionStatsToProfileActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :profile_activities, :activity_metrics, :json, null: false, default: {}
  end
end
