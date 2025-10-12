class CreateProfileScrapes < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_scrapes do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :url, null: false
      t.string :title
      t.string :description
      t.string :canonical_url
      t.string :content_type
      t.integer :http_status
      t.integer :bytes
      t.datetime :fetched_at
      t.text :text
      t.json :links
      t.timestamps
    end
    add_index :profile_scrapes, [ :profile_id, :url ], unique: true
  end
end
