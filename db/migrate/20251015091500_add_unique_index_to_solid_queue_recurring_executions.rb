class AddUniqueIndexToSolidQueueRecurringExecutions < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:solid_queue_recurring_executions)

    add_index :solid_queue_recurring_executions,
      [ :task_key, :run_at ],
      unique: true,
      name: "index_solid_queue_recurring_executions_on_task_key_and_run_at",
      if_not_exists: true
  end
end
