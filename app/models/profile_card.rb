class ProfileCard < ApplicationRecord
  belongs_to :profile

  validates :attack, :defense, :speed, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def tags_array
    Array(tags)
  end
end
