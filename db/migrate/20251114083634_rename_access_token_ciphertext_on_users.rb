class RenameAccessTokenCiphertextOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :access_token_ciphertext, :access_token
  end
end
