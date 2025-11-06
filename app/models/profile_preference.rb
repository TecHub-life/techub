class ProfilePreference < ApplicationRecord
  belongs_to :profile

  SORT_MODES = %w[manual alphabetical oldest newest].freeze
  DATE_FORMATS = %w[yyyy_mm_dd dd_mm_yyyy relative].freeze
  TIME_DISPLAY = %w[local utc relative profile_default].freeze
  STYLE_VARIANTS = ProfileShowcaseItem::STYLE_VARIANTS
  STYLE_ACCENTS = ProfileShowcaseItem::STYLE_ACCENTS
  STYLE_SHAPES = ProfileShowcaseItem::STYLE_SHAPES

  validates :links_sort_mode, inclusion: { in: SORT_MODES }
  validates :achievements_sort_mode, inclusion: { in: SORT_MODES }
  validates :experiences_sort_mode, inclusion: { in: SORT_MODES }
  validates :achievements_date_format, inclusion: { in: DATE_FORMATS }
  validates :achievements_time_display, inclusion: { in: TIME_DISPLAY }
  validates :default_style_variant, inclusion: { in: STYLE_VARIANTS }
  validates :default_style_accent, inclusion: { in: STYLE_ACCENTS }
  validates :default_style_shape, inclusion: { in: STYLE_SHAPES }
  validates :pin_limit, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }

  before_validation :normalize_defaults

  def sort_mode_for(kind)
    case kind.to_s
    when "links" then links_sort_mode
    when "achievements" then achievements_sort_mode
    when "experiences" then experiences_sort_mode
    else "manual"
    end
  end

  private

  def normalize_defaults
    self.links_sort_mode = normalize_sort_mode(links_sort_mode)
    self.achievements_sort_mode = normalize_sort_mode(achievements_sort_mode)
    self.experiences_sort_mode = normalize_sort_mode(experiences_sort_mode)
    self.achievements_date_format = normalize_date_format(achievements_date_format)
    self.achievements_time_display = normalize_time_display(achievements_time_display)
    self.default_style_variant = normalize_choice(default_style_variant, STYLE_VARIANTS, STYLE_VARIANTS.first)
    self.default_style_accent = normalize_choice(default_style_accent, STYLE_ACCENTS, STYLE_ACCENTS.second)
    self.default_style_shape = normalize_choice(default_style_shape, STYLE_SHAPES, STYLE_SHAPES.first)
    self.pin_limit ||= 5
  end

  def normalize_sort_mode(value)
    value = value.to_s.downcase
    SORT_MODES.include?(value) ? value : "manual"
  end

  def normalize_date_format(value)
    value = value.to_s.downcase
    DATE_FORMATS.include?(value) ? value : DATE_FORMATS.first
  end

  def normalize_time_display(value)
    value = value.to_s.downcase
    TIME_DISPLAY.include?(value) ? value : TIME_DISPLAY.first
  end

  def normalize_choice(value, allowed, fallback)
    value = value.to_s.downcase
    allowed.include?(value) ? value : fallback
  end
end
