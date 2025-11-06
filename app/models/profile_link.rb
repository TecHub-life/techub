class ProfileLink < ApplicationRecord
  include ProfileShowcaseItem

  MAX_DESCRIPTION = 500

  validates :label, presence: true, length: { maximum: 120 }
  validates :subtitle, length: { maximum: 160 }, allow_blank: true
  validates :url, length: { maximum: 2048 }, allow_blank: true
  validates :fa_icon, length: { maximum: 80 }, allow_blank: true
  validates :secret_code, length: { maximum: 64 }, allow_blank: true
  validate :properties_size_within_limit

  scope :alphabetical, -> { order(Arel.sql("lower(label) ASC")) }

  def inactive?
    !active?
  end

  def manual_position
    position || 0
  end

  private

  def properties_size_within_limit
    return if properties.blank?

    bytes = properties.to_s.bytesize
    errors.add(:properties, "is too large") if bytes > MAX_DESCRIPTION
  end
end
