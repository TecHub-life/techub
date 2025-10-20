# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_20_120002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "leaderboards", force: :cascade do |t|
    t.string "kind", null: false
    t.string "window", default: "30d", null: false
    t.date "as_of", null: false
    t.json "entries", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "window", "as_of"], name: "index_leaderboards_on_kind_and_window_and_as_of", unique: true
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "event", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "event", "subject_type", "subject_id"], name: "idx_delivery_uniqueness", unique: true
    t.index ["user_id"], name: "index_notification_deliveries_on_user_id"
  end

  create_table "profile_activities", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.integer "total_events", default: 0
    t.json "event_breakdown", default: {}
    t.text "recent_repos"
    t.datetime "last_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_active"], name: "index_profile_activities_on_last_active"
    t.index ["profile_id"], name: "index_profile_activities_on_profile_id"
  end

  create_table "profile_assets", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "kind", null: false
    t.string "provider"
    t.string "mime_type"
    t.integer "width"
    t.integer "height"
    t.string "local_path"
    t.string "public_url"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "kind"], name: "index_profile_assets_on_profile_id_and_kind", unique: true
    t.index ["profile_id"], name: "index_profile_assets_on_profile_id"
  end

  create_table "profile_cards", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "title"
    t.string "tagline"
    t.integer "attack", default: 0
    t.integer "defense", default: 0
    t.integer "speed", default: 0
    t.string "vibe"
    t.string "special_move"
    t.string "spirit_animal"
    t.string "archetype"
    t.json "tags", default: []
    t.string "style_profile"
    t.string "theme"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bg_choice_card", default: "ai", null: false
    t.string "bg_color_card"
    t.string "bg_choice_og", default: "ai", null: false
    t.string "bg_color_og"
    t.string "bg_choice_simple", default: "ai", null: false
    t.string "bg_color_simple"
    t.float "bg_fx_card"
    t.float "bg_fy_card"
    t.float "bg_zoom_card"
    t.float "bg_fx_og"
    t.float "bg_fy_og"
    t.float "bg_zoom_og"
    t.float "bg_fx_simple"
    t.float "bg_fy_simple"
    t.float "bg_zoom_simple"
    t.text "short_bio"
    t.text "long_bio"
    t.string "buff"
    t.text "buff_description"
    t.string "weakness"
    t.text "weakness_description"
    t.string "flavor_text"
    t.string "playing_card"
    t.text "vibe_description"
    t.text "special_move_description"
    t.text "avatar_description"
    t.string "ai_model"
    t.string "prompt_version"
    t.string "avatar_choice", default: "real", null: false
    t.index ["archetype"], name: "index_profile_cards_on_archetype"
    t.index ["profile_id"], name: "index_profile_cards_on_profile_id", unique: true
    t.index ["spirit_animal"], name: "index_profile_cards_on_spirit_animal"
  end

  create_table "profile_languages", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "name", null: false
    t.integer "count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_profile_languages_on_name"
    t.index ["profile_id"], name: "index_profile_languages_on_profile_id"
  end

  create_table "profile_organizations", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "login", null: false
    t.string "name"
    t.string "avatar_url"
    t.text "description"
    t.string "html_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["login"], name: "index_profile_organizations_on_login"
    t.index ["profile_id"], name: "index_profile_organizations_on_profile_id"
  end

  create_table "profile_ownerships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_owner", default: false, null: false
    t.index ["profile_id"], name: "idx_one_owner_per_profile", unique: true, where: "is_owner = TRUE"
    t.index ["profile_id"], name: "index_profile_ownerships_on_profile_id"
    t.index ["user_id", "profile_id"], name: "index_profile_ownerships_on_user_id_and_profile_id", unique: true
    t.index ["user_id"], name: "index_profile_ownerships_on_user_id"
  end

  create_table "profile_pipeline_events", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "stage", null: false
    t.string "status", null: false
    t.integer "duration_ms"
    t.string "message"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_profile_pipeline_events_on_created_at"
    t.index ["profile_id"], name: "index_profile_pipeline_events_on_profile_id"
  end

  create_table "profile_readmes", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_profile_readmes_on_profile_id"
  end

  create_table "profile_repositories", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "name", null: false
    t.string "full_name"
    t.text "description"
    t.string "html_url"
    t.integer "stargazers_count", default: 0
    t.integer "forks_count", default: 0
    t.string "language"
    t.string "repository_type", null: false
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "repository_type"], name: "index_profile_repositories_on_profile_id_and_repository_type"
    t.index ["profile_id"], name: "index_profile_repositories_on_profile_id"
    t.index ["stargazers_count"], name: "index_profile_repositories_on_stargazers_count"
  end

  create_table "profile_scrapes", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "url", null: false
    t.string "title"
    t.string "description"
    t.string "canonical_url"
    t.string "content_type"
    t.integer "http_status"
    t.integer "bytes"
    t.datetime "fetched_at"
    t.text "text"
    t.json "links"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "url"], name: "index_profile_scrapes_on_profile_id_and_url", unique: true
    t.index ["profile_id"], name: "index_profile_scrapes_on_profile_id"
  end

  create_table "profile_social_accounts", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "provider", null: false
    t.string "url"
    t.string "display_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_profile_social_accounts_on_profile_id"
    t.index ["provider"], name: "index_profile_social_accounts_on_provider"
  end

  create_table "profiles", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "name"
    t.string "avatar_url"
    t.text "bio"
    t.string "company"
    t.string "location"
    t.string "blog"
    t.string "email"
    t.string "twitter_username"
    t.boolean "hireable", default: false
    t.string "html_url"
    t.integer "followers", default: 0
    t.integer "following", default: 0
    t.integer "public_repos", default: 0
    t.integer "public_gists", default: 0
    t.text "summary"
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "submitted_scrape_url"
    t.datetime "submitted_at"
    t.string "last_pipeline_status"
    t.text "last_pipeline_error"
    t.datetime "last_ai_regenerated_at"
    t.text "last_sync_error"
    t.datetime "last_sync_error_at"
    t.boolean "ai_art_opt_in", default: false, null: false
    t.index ["ai_art_opt_in"], name: "index_profiles_on_ai_art_opt_in"
    t.index ["followers"], name: "index_profiles_on_followers"
    t.index ["github_id"], name: "index_profiles_on_github_id", unique: true
    t.index ["hireable"], name: "index_profiles_on_hireable"
    t.index ["last_ai_regenerated_at"], name: "index_profiles_on_last_ai_regenerated_at"
    t.index ["last_synced_at"], name: "index_profiles_on_last_synced_at"
    t.index ["login"], name: "index_profiles_on_login", unique: true
  end

  create_table "repository_topics", force: :cascade do |t|
    t.integer "profile_repository_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_repository_topics_on_name"
    t.index ["profile_repository_id"], name: "index_repository_topics_on_profile_repository_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "name"
    t.string "avatar_url"
    t.string "access_token_ciphertext"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.boolean "notify_on_pipeline", default: true, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["login"], name: "index_users_on_login", unique: true
  end

  add_foreign_key "notification_deliveries", "users"
  add_foreign_key "profile_activities", "profiles"
  add_foreign_key "profile_assets", "profiles"
  add_foreign_key "profile_cards", "profiles"
  add_foreign_key "profile_languages", "profiles"
  add_foreign_key "profile_organizations", "profiles"
  add_foreign_key "profile_ownerships", "profiles"
  add_foreign_key "profile_ownerships", "users"
  add_foreign_key "profile_readmes", "profiles"
  add_foreign_key "profile_repositories", "profiles"
  add_foreign_key "profile_scrapes", "profiles"
  add_foreign_key "profile_social_accounts", "profiles"
  add_foreign_key "repository_topics", "profile_repositories"
end
