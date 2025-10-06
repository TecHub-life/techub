class ProfileOrganization < ApplicationRecord
  belongs_to :profile

  validates :login, presence: true

  scope :with_names, -> { where.not(name: [ nil, "" ]) }
  scope :with_descriptions, -> { where.not(description: [ nil, "" ]) }

  def display_name
    name.presence || login
  end

  def github_url
    html_url || "https://github.com/#{login}"
  end

  def has_description?
    description.present?
  end
end
