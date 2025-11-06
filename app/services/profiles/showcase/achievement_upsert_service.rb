module Profiles
  module Showcase
    class AchievementUpsertService < BaseService
      attr_reader :achievement, :attributes

      def initialize(profile:, attributes:, achievement: nil, actor: nil)
        super(profile: profile, actor: actor)
        @achievement = achievement
        @attributes = attributes || {}
      end

      def call
        record = achievement || profile.profile_achievements.new
        was_pinned = record.pinned?

        apply_attributes(record)

        if record.pinned? && !can_pin?(was_pinned)
          return failure("Pin limit reached (#{profile.showcase_pin_limit})")
        end

        record.position ||= next_position(profile.profile_achievements)
        record.pin_position ||= record.position

        if record.save
          log_action("achievement.saved", id: record.id)
          success(record)
        else
          failure(record.errors.full_messages.to_sentence)
        end
      end

      private

      def apply_attributes(record)
        record.title = attributes[:title]
        record.description = normalize_blank(attributes[:description])
        record.url = normalize_blank(attributes[:url])
        record.fa_icon = normalize_blank(attributes[:fa_icon])
        record.date_display_mode = normalize_blank(attributes[:date_display_mode]) || record.date_display_mode
        record.pin_surface = normalize_blank(attributes[:pin_surface]) || record.pin_surface || "spotlight"
        record.style_variant = normalize_blank(attributes[:style_variant])
        record.style_accent = normalize_blank(attributes[:style_accent])
        record.style_shape = normalize_blank(attributes[:style_shape])

        %i[active hidden pinned].each do |flag|
          next unless attributes.key?(flag)
          record.public_send("#{flag}=", boolean(attributes[flag]))
        end

        if attributes.key?(:occurred_on)
          record.occurred_on = parse_date(attributes[:occurred_on])
        elsif record.occurred_at.present?
          record.occurred_on ||= record.occurred_at.to_date
        end

        if attributes.key?(:position)
          record.position = integer(attributes[:position]) || record.position
        end

        if attributes.key?(:pin_position)
          record.pin_position = integer(attributes[:pin_position]) || record.pin_position
        end
      end

      def next_position(scope)
        scope.maximum(:position).to_i + 1
      end
    end
  end
end
