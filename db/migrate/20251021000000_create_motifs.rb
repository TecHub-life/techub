class CreateMotifs < ActiveRecord::Migration[8.0]
  def change
    create_table :motifs do |t|
      t.string :kind, null: false # "archetype" | "spirit_animal"
      t.string :name, null: false
      t.string :slug, null: false
      t.string :theme, null: false, default: "core"

      t.text :short_lore
      t.text :long_lore

      t.string :image_1x1_path
      t.string :image_16x9_path

      t.timestamps
    end

    add_index :motifs, [ :kind, :slug, :theme ], unique: true
    add_index :motifs, :kind
    add_index :motifs, :theme
  end
end


