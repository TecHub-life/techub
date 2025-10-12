class AddSubmittedFields < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :submitted_scrape_url, :string
  end
end
