class AddBgChoicesToProfileCards < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_cards, :bg_choice_card, :string, default: "ai", null: false
    add_column :profile_cards, :bg_color_card, :string
    add_column :profile_cards, :bg_choice_og, :string, default: "ai", null: false
    add_column :profile_cards, :bg_color_og, :string
    add_column :profile_cards, :bg_choice_simple, :string, default: "ai", null: false
    add_column :profile_cards, :bg_color_simple, :string
  end
end
