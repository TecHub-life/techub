class ProfilePipelineEvent < ApplicationRecord
  belongs_to :profile
  validates :stage, :status, presence: true
end
