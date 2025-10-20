class AddImageUrlsToMotifs < ActiveRecord::Migration[8.0]
  def change
    add_column :motifs, :image_1x1_url, :string
    add_column :motifs, :image_16x9_url, :string
    add_index :motifs, :image_1x1_url
    add_index :motifs, :image_16x9_url
  end
end
