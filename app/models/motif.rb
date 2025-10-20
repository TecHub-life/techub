class Motif < ApplicationRecord
  KINDS = %w[archetype spirit_animal].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :name, :slug, :theme, presence: true
end
