class ProfileReadme < ApplicationRecord
  belongs_to :profile

  validates :content, presence: true

  def word_count
    content.split.count
  end

  def character_count
    content.length
  end

  def is_long?
    character_count > 5000
  end

  def truncated_content(limit = 5000)
    return content if character_count <= limit

    content[0, limit] + "..."
  end

  def markdown?
    content.include?("#") || content.include?("*") || content.include?("[")
  end
end
