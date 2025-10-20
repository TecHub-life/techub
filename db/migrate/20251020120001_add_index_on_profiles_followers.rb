class AddIndexOnProfilesFollowers < ActiveRecord::Migration[8.0]
  def change
    add_index :profiles, :followers unless index_exists?(:profiles, :followers)
  end
end

