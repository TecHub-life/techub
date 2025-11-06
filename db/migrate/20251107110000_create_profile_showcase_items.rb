class CreateProfileShowcaseItems < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_preferences do |t|
      t.references :profile, null: false, foreign_key: true, index: { unique: true }
      t.string :links_sort_mode, null: false, default: "manual"
      t.string :achievements_sort_mode, null: false, default: "manual"
      t.string :experiences_sort_mode, null: false, default: "manual"
      t.string :default_style_variant, null: false, default: "plain"
      t.string :default_style_accent, null: false, default: "medium"
      t.string :default_style_shape, null: false, default: "rounded"
      t.string :achievements_date_format, null: false, default: "yyyy_mm_dd"
      t.string :achievements_time_display, null: false, default: "local"
      t.boolean :achievements_dual_time, null: false, default: false
      t.integer :pin_limit, null: false, default: 5
      t.json :metadata, default: {}
      t.timestamps
    end

    create_table :profile_links do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :label, null: false
      t.string :subtitle
      t.string :url
      t.string :fa_icon
      t.boolean :active, null: false, default: true
      t.boolean :hidden, null: false, default: false
      t.boolean :pinned, null: false, default: false
      t.string :pin_surface, null: false, default: "hero"
      t.integer :pin_position
      t.integer :position, null: false, default: 0
      t.string :style_variant
      t.string :style_accent
      t.string :style_shape
      t.string :secret_code
      t.json :properties, default: {}
      t.timestamps
    end
    add_index :profile_links, [ :profile_id, :position ]
    add_index :profile_links, [ :profile_id, :pinned ]
    add_index :profile_links, :secret_code, unique: true

    create_table :profile_achievements do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.datetime :occurred_at
      t.date :occurred_on
      t.string :timezone, null: false, default: "Australia/Melbourne"
      t.string :date_display_mode, null: false, default: "profile_default"
      t.boolean :active, null: false, default: true
      t.boolean :hidden, null: false, default: false
      t.boolean :pinned, null: false, default: false
      t.string :pin_surface, null: false, default: "spotlight"
      t.integer :pin_position
      t.integer :position, null: false, default: 0
      t.string :style_variant
      t.string :style_accent
      t.string :style_shape
      t.json :properties, default: {}
      t.timestamps
    end
    add_index :profile_achievements, [ :profile_id, :position ], name: "idx_profile_achievements_order"
    add_index :profile_achievements, [ :profile_id, :pinned ], name: "idx_profile_achievements_pins"
    add_index :profile_achievements, :occurred_at

    create_table :profile_experiences do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :title, null: false
      t.string :employment_type
      t.string :organization
      t.string :organization_url
      t.boolean :current_role, null: false, default: false
      t.date :started_on
      t.date :ended_on
      t.string :location
      t.string :location_type
      t.string :location_timezone
      t.text :description
      t.boolean :active, null: false, default: true
      t.boolean :hidden, null: false, default: false
      t.boolean :pinned, null: false, default: false
      t.string :pin_surface, null: false, default: "hero"
      t.integer :pin_position
      t.integer :position, null: false, default: 0
      t.string :style_variant
      t.string :style_accent
      t.string :style_shape
      t.json :properties, default: {}
      t.timestamps
    end
    add_index :profile_experiences, [ :profile_id, :position ], name: "idx_profile_experiences_order"
    add_index :profile_experiences, [ :profile_id, :pinned ], name: "idx_profile_experiences_pins"
    add_index :profile_experiences, [ :profile_id, :current_role ]

    create_table :profile_experience_skills do |t|
      t.references :profile_experience, null: false, foreign_key: true, index: { name: "idx_experience_skills_on_experience" }
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :profile_experience_skills, [ :profile_experience_id, :name ], unique: true, name: "idx_experience_skills_uniqueness"
  end
end
