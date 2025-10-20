class AddIndexesOnProfileCardsTraits < ActiveRecord::Migration[8.0]
  def change
    add_index :profile_cards, :archetype unless index_exists?(:profile_cards, :archetype)
    add_index :profile_cards, :spirit_animal unless index_exists?(:profile_cards, :spirit_animal)
  end
end
