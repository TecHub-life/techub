class RenameProfileCardsModelNameToAiModel < ActiveRecord::Migration[8.0]
  def change
    # Avoid collision with ActiveRecord::Base#model_name
    if column_exists?(:profile_cards, :model_name)
      rename_column :profile_cards, :model_name, :ai_model
    end
  end
end
