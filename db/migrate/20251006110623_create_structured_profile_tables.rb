class CreateStructuredProfileTables < ActiveRecord::Migration[8.0]
  def change
    # Drop old profiles table if it exists
    drop_table :profiles, if_exists: true

    # Create new structured profiles table
    create_table :profiles do |t|
      # Basic profile info
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :name
      t.string :avatar_url
      t.text :bio
      t.string :company
      t.string :location
      t.string :blog
      t.string :email
      t.string :twitter_username
      t.boolean :hireable, default: false
      t.string :html_url

      # Stats
      t.integer :followers, default: 0
      t.integer :following, default: 0
      t.integer :public_repos, default: 0
      t.integer :public_gists, default: 0

      # Metadata
      t.text :summary  # AI-generated summary
      t.datetime :github_created_at
      t.datetime :github_updated_at
      t.datetime :last_synced_at
      t.timestamps

      t.index [ :github_id ], unique: true
      t.index [ :login ], unique: true
      t.index [ :hireable ]
      t.index [ :last_synced_at ]
    end

    # Profile repositories table
    create_table :profile_repositories do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :name, null: false
      t.string :full_name
      t.text :description
      t.string :html_url
      t.integer :stargazers_count, default: 0
      t.integer :forks_count, default: 0
      t.string :language
      t.string :repository_type, null: false  # 'top', 'pinned', 'active'
      t.datetime :github_created_at
      t.datetime :github_updated_at
      t.timestamps

      t.index [ :profile_id, :repository_type ]
      t.index [ :stargazers_count ]
    end

    # Repository topics table
    create_table :repository_topics do |t|
      t.references :profile_repository, null: false, foreign_key: true, index: true
      t.string :name, null: false, index: true
      t.timestamps
    end

    # Profile organizations table
    create_table :profile_organizations do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :login, null: false, index: true
      t.string :name
      t.string :avatar_url
      t.text :description
      t.string :html_url
      t.timestamps
    end

    # Profile social accounts table
    create_table :profile_social_accounts do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :provider, null: false, index: true  # 'TWITTER', 'BLUESKY', etc.
      t.string :url
      t.string :display_name
      t.timestamps
    end

    # Profile languages table
    create_table :profile_languages do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :name, null: false, index: true
      t.integer :count, default: 0
      t.timestamps
    end

    # Profile activity table
    create_table :profile_activities do |t|
      t.references :profile, null: false, foreign_key: true
      t.integer :total_events, default: 0
      t.json :event_breakdown, default: {}
      t.text :recent_repos  # Store as JSON array string
      t.datetime :last_active, index: true
      t.timestamps
    end

    # Profile READMEs table
    create_table :profile_readmes do |t|
      t.references :profile, null: false, foreign_key: true
      t.text :content
      t.timestamps
    end
  end
end
