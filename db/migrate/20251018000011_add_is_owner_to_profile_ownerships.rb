class AddIsOwnerToProfileOwnerships < ActiveRecord::Migration[8.0]
  def change
    # Simplify: a single boolean indicates rightful ownership (canonical owner)
    add_column :profile_ownerships, :is_owner, :boolean, null: false, default: false
    # Ensure a single owner per profile (partial unique index)
    add_index :profile_ownerships, :profile_id, if_not_exists: true
    add_index :profile_ownerships, [ :profile_id ], name: "idx_one_owner_per_profile", unique: true, where: "is_owner = TRUE", if_not_exists: true
  end
end
