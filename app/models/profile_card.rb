class ProfileCard < ApplicationRecord
  belongs_to :profile

  validates :attack, :defense, :speed, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :stats_bounds
  validate :tags_size_and_format
  validates :playing_card, format: { with: /\A(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]\z/, allow_blank: true }
  validates :archetype, inclusion: { in: ->(_) { Motifs::Catalog.archetype_names }, allow_blank: true }
  validates :spirit_animal, inclusion: { in: ->(_) { Motifs::Catalog.spirit_animal_names }, allow_blank: true }

  before_validation :normalize_tags

  def tags_array
    Array(tags)
  end

  # Convenience accessor maintained for API consumers; map old name to new column
  def model_name
    self[:ai_model]
  end

  private

  def stats_bounds
    %i[attack defense speed].each do |k|
      v = self.send(k).to_i
      if v < 0 || v > 100
        errors.add(k, "must be between 0 and 100")
      end
    end
  end

  def tags_size_and_format
    arr = Array(tags).map(&:to_s).reject(&:blank?)
    if arr.length > 0 && arr.length != 6
      errors.add(:tags, "must contain exactly 6 items")
    end
    unless arr.all? { |t| t =~ /\A[a-z0-9]+(?:-[a-z0-9]+){0,2}\z/ }
      errors.add(:tags, "must be lowercase kebab-case (1–3 words)")
    end
  end

  def normalize_tags
    self.tags = Array(tags).map { |t| t.to_s.downcase.strip.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-") }.reject(&:blank?).uniq if self.tags_changed?
  end
end
