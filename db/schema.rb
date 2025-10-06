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

ActiveRecord::Schema[8.0].define(version: 2025_10_06_110623) do
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
    t.index ["github_id"], name: "index_profiles_on_github_id", unique: true
    t.index ["hireable"], name: "index_profiles_on_hireable"
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
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["login"], name: "index_users_on_login", unique: true
  end

  add_foreign_key "profile_activities", "profiles"
  add_foreign_key "profile_languages", "profiles"
  add_foreign_key "profile_organizations", "profiles"
  add_foreign_key "profile_readmes", "profiles"
  add_foreign_key "profile_repositories", "profiles"
  add_foreign_key "profile_social_accounts", "profiles"
  add_foreign_key "repository_topics", "profile_repositories"
end
