class ProfileAsset < ApplicationRecord
  belongs_to :profile
  validates :kind, presence: true
end
