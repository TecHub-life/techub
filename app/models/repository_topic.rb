class RepositoryTopic < ApplicationRecord
  belongs_to :profile_repository

  validates :name, presence: true

  scope :popular, -> { group(:name).order("count(*) desc") }
end
