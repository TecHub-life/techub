module ProfileShowcaseItem
  extend ActiveSupport::Concern

  STYLE_VARIANTS = %w[plain rainbow animated outline glass mono].freeze
  STYLE_ACCENTS = %w[subtle medium bold].freeze
  STYLE_SHAPES = %w[rounded pill card].freeze
  PIN_SURFACES = %w[hero spotlight shelf timeline].freeze

  included do
    belongs_to :profile

    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
    scope :visible, -> { active.where(hidden: false) }
    scope :hidden_only, -> { where(hidden: true) }
    scope :pinned, -> { where(pinned: true) }
    scope :ordered, -> { order(Arel.sql("COALESCE(position, 0) ASC")) }

    validates :style_variant, inclusion: { in: STYLE_VARIANTS }, allow_blank: true
    validates :style_accent, inclusion: { in: STYLE_ACCENTS }, allow_blank: true
    validates :style_shape, inclusion: { in: STYLE_SHAPES }, allow_blank: true
    validates :pin_surface, inclusion: { in: PIN_SURFACES }

    before_validation :normalize_style_defaults
  end

  def applied_style_variant
    style_variant.presence || profile.preference_default(:default_style_variant, STYLE_VARIANTS.first)
  end

  def applied_style_accent
    style_accent.presence || profile.preference_default(:default_style_accent, STYLE_ACCENTS.second)
  end

  def applied_style_shape
    style_shape.presence || profile.preference_default(:default_style_shape, STYLE_SHAPES.first)
  end

  private

  def normalize_style_defaults
    self.pin_surface = "hero" if pin_surface.blank?
    self.style_variant = nil unless STYLE_VARIANTS.include?(style_variant)
    self.style_accent = nil unless STYLE_ACCENTS.include?(style_accent)
    self.style_shape = nil unless STYLE_SHAPES.include?(style_shape)
  end
end
