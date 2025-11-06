class CreateAhoyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ahoy_visits do |t|
      t.string :visit_token
      t.string :visitor_token
      t.integer :user_id
      t.string :ip
      t.text :user_agent
      t.text :referrer
      t.text :landing_page
      t.text :device_type
      t.text :country
      t.text :region
      t.text :city
      t.text :utm_source
      t.text :utm_medium
      t.text :utm_term
      t.text :utm_content
      t.text :utm_campaign
      t.string :app_version
      t.string :os_version
      t.datetime :started_at
    end

    add_index :ahoy_visits, :visit_token, unique: true
    add_index :ahoy_visits, :visitor_token
    add_index :ahoy_visits, [ :visitor_token, :started_at ]

    create_table :ahoy_events do |t|
      t.references :visit, foreign_key: { to_table: :ahoy_visits }
      t.integer :user_id
      t.string :name
      t.json :properties
      t.datetime :time
    end

    add_index :ahoy_events, :name
  end
end
