class CreateProfileCards < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_cards do |t|
      t.references :profile, null: false, index: { unique: true }, foreign_key: true
      t.string :title
      t.string :tagline
      t.integer :attack, default: 0
      t.integer :defense, default: 0
      t.integer :speed, default: 0
      t.string :vibe
      t.string :special_move
      t.string :spirit_animal
      t.string :archetype
      t.json :tags, default: []
      t.string :style_profile
      t.string :theme
      t.datetime :generated_at
      t.timestamps
    end
  end
end
