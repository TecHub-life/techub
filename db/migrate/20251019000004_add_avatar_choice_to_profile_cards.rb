class AddAvatarChoiceToProfileCards < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_cards, :avatar_choice, :string, default: "real", null: false
  end
end
