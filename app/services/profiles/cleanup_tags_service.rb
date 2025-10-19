module Profiles
  class CleanupTagsService < ApplicationService
    def initialize(limit: 500)
      @limit = limit.to_i
    end

    def call
      cleaned = 0
      scope = Profile.joins(:profile_card).limit(limit)
      scope.find_each do |profile|
        card = profile.profile_card
        next unless card
        tags = Array(card.tags).map { |t| t.to_s.downcase.strip }.reject(&:blank?).uniq
        if tags != card.tags
          card.update(tags: tags)
          cleaned += 1
        end
      end
      StructuredLogger.info(message: "cleanup_tags_completed", cleaned: cleaned) if defined?(StructuredLogger)
      success({ cleaned: cleaned })
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :limit
  end
end
