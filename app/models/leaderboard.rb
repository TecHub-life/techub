class Leaderboard < ApplicationRecord
  KINDS = %w[
    followers_total
    followers_gain_7d
    followers_gain_30d
    stars_total
    stars_gain_7d
    stars_gain_30d
    repos_most_starred
  ].freeze

  WINDOWS = %w[7d 30d 90d all].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :window, inclusion: { in: WINDOWS }
  validates :as_of, presence: true

  def top(n = 50)
    Array(entries).first(n)
  end
end
