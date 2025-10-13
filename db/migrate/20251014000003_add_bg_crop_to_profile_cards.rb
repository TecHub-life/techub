class AddBgCropToProfileCards < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_cards, :bg_fx_card, :float
    add_column :profile_cards, :bg_fy_card, :float
    add_column :profile_cards, :bg_zoom_card, :float

    add_column :profile_cards, :bg_fx_og, :float
    add_column :profile_cards, :bg_fy_og, :float
    add_column :profile_cards, :bg_zoom_og, :float

    add_column :profile_cards, :bg_fx_simple, :float
    add_column :profile_cards, :bg_fy_simple, :float
    add_column :profile_cards, :bg_zoom_simple, :float
  end
end
