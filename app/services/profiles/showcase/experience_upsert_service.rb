module Profiles
  module Showcase
    class ExperienceUpsertService < BaseService
      attr_reader :experience, :attributes

      def initialize(profile:, attributes:, experience: nil, actor: nil)
        super(profile: profile, actor: actor)
        @experience = experience
        @attributes = attributes || {}
      end

      def call
        record = experience || profile.profile_experiences.new
        was_pinned = record.pinned?

        apply_attributes(record)

        if record.pinned? && !can_pin?(was_pinned)
          return failure("Pin limit reached (#{profile.showcase_pin_limit})")
        end

        record.position ||= next_position(profile.profile_experiences)
        record.pin_position ||= record.position

        unless record.save
          return failure(record.errors.full_messages.to_sentence)
        end

        unless sync_skills(record)
          return failure(record.errors.full_messages.to_sentence.presence || "Unable to save skills")
        end
        log_action("experience.saved", id: record.id)
        success(record)
      end

      private

      def apply_attributes(record)
        record.title = attributes[:title]
        record.employment_type = normalize_blank(attributes[:employment_type])
        record.organization = normalize_blank(attributes[:organization])
        record.organization_url = normalize_blank(attributes[:organization_url])
        record.location = normalize_blank(attributes[:location])
        record.location_type = normalize_blank(attributes[:location_type])
        record.location_timezone = normalize_blank(attributes[:location_timezone])
        record.description = normalize_blank(attributes[:description])
        record.pin_surface = normalize_blank(attributes[:pin_surface]) || record.pin_surface || "hero"
        record.style_variant = normalize_blank(attributes[:style_variant])
        record.style_accent = normalize_blank(attributes[:style_accent])
        record.style_shape = normalize_blank(attributes[:style_shape])

        %i[active hidden pinned current_role].each do |flag|
          next unless attributes.key?(flag)
          record.public_send("#{flag}=", boolean(attributes[flag]))
        end

        if attributes.key?(:started_on)
          record.started_on = parse_month_to_date(attributes[:started_on])
        end

        if attributes.key?(:ended_on)
          record.ended_on = parse_month_to_date(attributes[:ended_on])
        end

        if record.current_role?
          record.ended_on = nil
        end

        if attributes.key?(:position)
          record.position = integer(attributes[:position]) || record.position
        end

        if attributes.key?(:pin_position)
          record.pin_position = integer(attributes[:pin_position]) || record.pin_position
        end
      end

      def sync_skills(record)
        return unless attributes.key?(:skills_text)

        names = attributes[:skills_text].to_s.split(/[,\n]/).map { |token| token.strip }.reject(&:blank?).uniq.first(25)
        record.profile_experience_skills.destroy_all
        names.each_with_index do |name, idx|
          record.profile_experience_skills.create(name: name, position: idx)
        end
      end

      def next_position(scope)
        scope.maximum(:position).to_i + 1
      end
    end
  end
end
