class AddAppearanceSources < ActiveRecord::Migration[8.0]
  def up
    add_column :profile_cards, :avatar_sources, :jsonb, default: {}, null: false
    add_column :profile_cards, :bg_sources, :jsonb, default: {}, null: false

    change_column_default :profile_cards, :bg_choice_card, from: "ai", to: "library"
    change_column_default :profile_cards, :bg_choice_og, from: "ai", to: "library"
    change_column_default :profile_cards, :bg_choice_simple, from: "ai", to: "library"

    execute <<~SQL
      UPDATE profile_cards
      SET bg_choice_card = 'library'
      WHERE bg_choice_card IN ('ai', 'default') OR bg_choice_card IS NULL
    SQL

    execute <<~SQL
      UPDATE profile_cards
      SET bg_choice_og = 'library'
      WHERE bg_choice_og IN ('ai', 'default') OR bg_choice_og IS NULL
    SQL

    execute <<~SQL
      UPDATE profile_cards
      SET bg_choice_simple = 'library'
      WHERE bg_choice_simple IN ('ai', 'default') OR bg_choice_simple IS NULL
    SQL

    add_column :profiles, :banner_choice, :string, default: 'none', null: false
    add_column :profiles, :banner_library_path, :string
  end

  def down
    remove_column :profile_cards, :avatar_sources
    remove_column :profile_cards, :bg_sources

    change_column_default :profile_cards, :bg_choice_card, from: "library", to: "ai"
    change_column_default :profile_cards, :bg_choice_og, from: "library", to: "ai"
    change_column_default :profile_cards, :bg_choice_simple, from: "library", to: "ai"

    execute <<~SQL
      UPDATE profile_cards
      SET bg_choice_card = 'ai'
      WHERE bg_choice_card = 'library'
    SQL

    execute <<~SQL
      UPDATE profile_cards
      SET bg_choice_og = 'ai'
      WHERE bg_choice_og = 'library'
    SQL

    execute <<~SQL
      UPDATE profile_cards
      SET bg_choice_simple = 'ai'
      WHERE bg_choice_simple = 'library'
    SQL

    remove_column :profiles, :banner_choice
    remove_column :profiles, :banner_library_path
  end
end
