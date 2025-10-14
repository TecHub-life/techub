class AddAiFieldsToProfileCards < ActiveRecord::Migration[8.0]
  def change
    change_table :profile_cards, bulk: true do |t|
      t.text :short_bio
      t.text :long_bio
      t.string :buff
      t.text :buff_description
      t.string :weakness
      t.text :weakness_description
      t.string :flavor_text
      t.string :playing_card
      t.text :vibe_description
      t.text :special_move_description
      t.text :avatar_description
      t.string :model_name
      t.string :prompt_version
    end
  end
end
