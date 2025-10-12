class AddEmailAndNotifyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email, :string
    add_column :users, :notify_on_pipeline, :boolean, default: true, null: false
    add_index :users, :email, unique: true
  end
end
