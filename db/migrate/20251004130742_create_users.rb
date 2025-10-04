class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :name
      t.string :avatar_url
      t.string :access_token_ciphertext

      t.timestamps
    end

    add_index :users, :github_id, unique: true
    add_index :users, :login, unique: true
  end
end
