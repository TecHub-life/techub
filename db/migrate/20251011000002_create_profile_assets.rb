class CreateProfileAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_assets do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :kind, null: false # og|card|simple|avatar_1x1|avatar_16x9|...
      t.string :provider # ai_studio|vertex|screenshot
      t.string :mime_type
      t.integer :width
      t.integer :height
      t.string :local_path
      t.string :public_url
      t.datetime :generated_at
      t.timestamps
    end
    add_index :profile_assets, [ :profile_id, :kind ], unique: true
  end
end
