module Profiles
  module Showcase
    class LinkUpsertService < BaseService
      attr_reader :link, :attributes

      def initialize(profile:, attributes:, link: nil, actor: nil)
        super(profile: profile, actor: actor)
        @link = link
        @attributes = attributes || {}
      end

      def call
        record = link || profile.profile_links.new
        was_pinned = record.pinned?

        apply_attributes(record)

        if record.pinned? && !can_pin?(was_pinned)
          return failure("Pin limit reached (#{profile.showcase_pin_limit})")
        end

        record.position ||= next_position(profile.profile_links)
        record.pin_position ||= record.position

        if record.save
          log_action("link.saved", id: record.id)
          success(record)
        else
          failure(record.errors.full_messages.to_sentence)
        end
      end

      private

      def apply_attributes(record)
        record.label = attributes[:label]
        record.subtitle = normalize_blank(attributes[:subtitle])
        record.url = normalize_blank(attributes[:url])
        record.fa_icon = normalize_blank(attributes[:fa_icon])
        record.secret_code = normalize_blank(attributes[:secret_code])
        record.style_variant = normalize_blank(attributes[:style_variant])
        record.style_accent = normalize_blank(attributes[:style_accent])
        record.style_shape = normalize_blank(attributes[:style_shape])
        record.pin_surface = normalize_blank(attributes[:pin_surface]) || record.pin_surface || "hero"

        %i[active hidden pinned].each do |flag|
          next unless attributes.key?(flag)
          record.public_send("#{flag}=", boolean(attributes[flag]))
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
