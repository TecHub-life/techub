class ProfileLanguage < ApplicationRecord
  belongs_to :profile

  validates :name, presence: true
  validates :count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :popular, -> { order(count: :desc) }
  scope :by_name, ->(name) { where(name: name) }

  def percentage_of_total
    return 0 if profile.profile_languages.sum(:count).zero?

    (count * 100.0 / profile.profile_languages.sum(:count)).round(1)
  end
end
