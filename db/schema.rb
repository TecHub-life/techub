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

ActiveRecord::Schema[8.1].define(version: 2025_11_07_104826) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "leaderboards", force: :cascade do |t|
    t.date "as_of", null: false
    t.datetime "created_at", null: false
    t.json "entries", default: [], null: false
    t.string "kind", null: false
    t.datetime "updated_at", null: false
    t.string "window", default: "30d", null: false
    t.index ["kind", "window", "as_of"], name: "index_leaderboards_on_kind_and_window_and_as_of", unique: true
  end

  create_table "motifs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image_16x9_path"
    t.string "image_16x9_url"
    t.string "image_1x1_path"
    t.string "image_1x1_url"
    t.string "kind", null: false
    t.text "long_lore"
    t.string "name", null: false
    t.text "short_lore"
    t.string "slug", null: false
    t.string "theme", default: "core", null: false
    t.datetime "updated_at", null: false
    t.index ["image_16x9_url"], name: "index_motifs_on_image_16x9_url"
    t.index ["image_1x1_url"], name: "index_motifs_on_image_1x1_url"
    t.index ["kind", "slug", "theme"], name: "index_motifs_on_kind_and_slug_and_theme", unique: true
    t.index ["kind"], name: "index_motifs_on_kind"
    t.index ["theme"], name: "index_motifs_on_theme"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "event", null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "event", "subject_type", "subject_id"], name: "idx_delivery_uniqueness", unique: true
    t.index ["user_id"], name: "index_notification_deliveries_on_user_id"
  end

  create_table "profile_activities", force: :cascade do |t|
    t.json "activity_metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.json "event_breakdown", default: {}
    t.datetime "last_active"
    t.integer "profile_id", null: false
    t.text "recent_repos"
    t.integer "total_events", default: 0
    t.datetime "updated_at", null: false
    t.index ["last_active"], name: "index_profile_activities_on_last_active"
    t.index ["profile_id"], name: "index_profile_activities_on_profile_id"
  end

  create_table "profile_assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "generated_at"
    t.integer "height"
    t.string "kind", null: false
    t.string "local_path"
    t.string "mime_type"
    t.integer "profile_id", null: false
    t.string "provider"
    t.string "public_url"
    t.datetime "updated_at", null: false
    t.integer "width"
    t.index ["profile_id", "kind"], name: "index_profile_assets_on_profile_id_and_kind", unique: true
    t.index ["profile_id"], name: "index_profile_assets_on_profile_id"
  end

  create_table "profile_cards", force: :cascade do |t|
    t.string "ai_model"
    t.string "archetype"
    t.integer "attack", default: 0
    t.string "avatar_choice", default: "real", null: false
    t.text "avatar_description"
    t.string "bg_choice_card", default: "ai", null: false
    t.string "bg_choice_og", default: "ai", null: false
    t.string "bg_choice_simple", default: "ai", null: false
    t.string "bg_color_card"
    t.string "bg_color_og"
    t.string "bg_color_simple"
    t.float "bg_fx_card"
    t.float "bg_fx_og"
    t.float "bg_fx_simple"
    t.float "bg_fy_card"
    t.float "bg_fy_og"
    t.float "bg_fy_simple"
    t.float "bg_zoom_card"
    t.float "bg_zoom_og"
    t.float "bg_zoom_simple"
    t.string "buff"
    t.text "buff_description"
    t.datetime "created_at", null: false
    t.integer "defense", default: 0
    t.string "flavor_text"
    t.datetime "generated_at"
    t.text "long_bio"
    t.string "playing_card"
    t.integer "profile_id", null: false
    t.string "prompt_version"
    t.text "short_bio"
    t.string "special_move"
    t.text "special_move_description"
    t.integer "speed", default: 0
    t.string "spirit_animal"
    t.string "style_profile"
    t.string "tagline"
    t.json "tags", default: []
    t.string "theme"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "vibe"
    t.text "vibe_description"
    t.string "weakness"
    t.text "weakness_description"
    t.index ["archetype"], name: "index_profile_cards_on_archetype"
    t.index ["profile_id"], name: "index_profile_cards_on_profile_id", unique: true
    t.index ["spirit_animal"], name: "index_profile_cards_on_spirit_animal"
  end

  create_table "profile_languages", force: :cascade do |t|
    t.integer "count", default: 0
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_profile_languages_on_name"
    t.index ["profile_id"], name: "index_profile_languages_on_profile_id"
  end

  create_table "profile_organizations", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "html_url"
    t.string "login", null: false
    t.string "name"
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["login"], name: "index_profile_organizations_on_login"
    t.index ["profile_id"], name: "index_profile_organizations_on_profile_id"
  end

  create_table "profile_ownerships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_owner", default: false, null: false
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["profile_id"], name: "idx_one_owner_per_profile", unique: true, where: "is_owner = TRUE"
    t.index ["profile_id"], name: "index_profile_ownerships_on_profile_id"
    t.index ["user_id", "profile_id"], name: "index_profile_ownerships_on_user_id_and_profile_id", unique: true
    t.index ["user_id"], name: "index_profile_ownerships_on_user_id"
  end

  create_table "profile_pipeline_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "message"
    t.integer "profile_id", null: false
    t.string "stage", null: false
    t.string "status", null: false
    t.string "trigger"
    t.index ["created_at"], name: "index_profile_pipeline_events_on_created_at"
    t.index ["profile_id"], name: "index_profile_pipeline_events_on_profile_id"
    t.index ["trigger"], name: "index_profile_pipeline_events_on_trigger"
  end

  create_table "profile_readmes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_profile_readmes_on_profile_id"
  end

  create_table "profile_repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "forks_count", default: 0
    t.string "full_name"
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.string "html_url"
    t.string "language"
    t.string "name", null: false
    t.integer "profile_id", null: false
    t.string "repository_type", null: false
    t.integer "stargazers_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["profile_id", "repository_type"], name: "index_profile_repositories_on_profile_id_and_repository_type"
    t.index ["profile_id"], name: "index_profile_repositories_on_profile_id"
    t.index ["stargazers_count"], name: "index_profile_repositories_on_stargazers_count"
  end

  create_table "profile_scrapes", force: :cascade do |t|
    t.integer "bytes"
    t.string "canonical_url"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "fetched_at"
    t.integer "http_status"
    t.json "links"
    t.integer "profile_id", null: false
    t.text "text"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["profile_id", "url"], name: "index_profile_scrapes_on_profile_id_and_url", unique: true
    t.index ["profile_id"], name: "index_profile_scrapes_on_profile_id"
  end

  create_table "profile_social_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.integer "profile_id", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["profile_id"], name: "index_profile_social_accounts_on_profile_id"
    t.index ["provider"], name: "index_profile_social_accounts_on_provider"
  end

  create_table "profile_stats", force: :cascade do |t|
    t.datetime "captured_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "followers", default: 0, null: false
    t.integer "following", default: 0, null: false
    t.integer "profile_id", null: false
    t.integer "public_repos", default: 0, null: false
    t.integer "repo_count", default: 0, null: false
    t.date "stat_date", null: false
    t.integer "total_forks", default: 0, null: false
    t.integer "total_stars", default: 0, null: false
    t.index ["profile_id", "stat_date"], name: "index_profile_stats_on_profile_id_and_stat_date", unique: true
    t.index ["profile_id"], name: "index_profile_stats_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.boolean "ai_art_opt_in", default: false, null: false
    t.string "avatar_url"
    t.text "bio"
    t.string "blog"
    t.string "company"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "followers", default: 0
    t.integer "following", default: 0
    t.datetime "github_created_at"
    t.bigint "github_id", null: false
    t.datetime "github_updated_at"
    t.boolean "hireable", default: false
    t.boolean "hireable_override"
    t.string "html_url"
    t.datetime "last_ai_regenerated_at"
    t.text "last_pipeline_error"
    t.string "last_pipeline_status"
    t.text "last_sync_error"
    t.datetime "last_sync_error_at"
    t.datetime "last_synced_at"
    t.boolean "listed", default: true, null: false
    t.string "location"
    t.string "login", null: false
    t.string "name"
    t.string "preferred_og_kind", default: "og", null: false
    t.integer "public_gists", default: 0
    t.integer "public_repos", default: 0
    t.datetime "submitted_at"
    t.string "submitted_scrape_url"
    t.text "summary"
    t.string "twitter_username"
    t.datetime "unlisted_at"
    t.datetime "updated_at", null: false
    t.index ["ai_art_opt_in"], name: "index_profiles_on_ai_art_opt_in"
    t.index ["followers"], name: "index_profiles_on_followers"
    t.index ["github_id"], name: "index_profiles_on_github_id", unique: true
    t.index ["hireable"], name: "index_profiles_on_hireable"
    t.index ["hireable_override"], name: "index_profiles_on_hireable_override"
    t.index ["last_ai_regenerated_at"], name: "index_profiles_on_last_ai_regenerated_at"
    t.index ["last_synced_at"], name: "index_profiles_on_last_synced_at"
    t.index ["listed"], name: "index_profiles_on_listed"
    t.index ["login"], name: "index_profiles_on_login", unique: true
    t.index ["preferred_og_kind"], name: "index_profiles_on_preferred_og_kind"
    t.index ["unlisted_at"], name: "index_profiles_on_unlisted_at"
  end

  create_table "repository_topics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "profile_repository_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_repository_topics_on_name"
    t.index ["profile_repository_id"], name: "index_repository_topics_on_profile_repository_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "access_token_ciphertext"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "name"
    t.boolean "notify_on_pipeline", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["login"], name: "index_users_on_login", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "notification_deliveries", "users"
  add_foreign_key "profile_activities", "profiles"
  add_foreign_key "profile_assets", "profiles"
  add_foreign_key "profile_cards", "profiles"
  add_foreign_key "profile_languages", "profiles"
  add_foreign_key "profile_organizations", "profiles"
  add_foreign_key "profile_ownerships", "profiles"
  add_foreign_key "profile_ownerships", "users"
  add_foreign_key "profile_pipeline_events", "profiles"
  add_foreign_key "profile_readmes", "profiles"
  add_foreign_key "profile_repositories", "profiles"
  add_foreign_key "profile_scrapes", "profiles"
  add_foreign_key "profile_social_accounts", "profiles"
  add_foreign_key "profile_stats", "profiles"
  add_foreign_key "repository_topics", "profile_repositories"
end
