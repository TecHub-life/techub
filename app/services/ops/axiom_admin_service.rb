# frozen_string_literal: true

module Ops
  class AxiomAdminService
    FIELD_LIMIT = 256
    TOP_PARENTS_DEFAULT = 10

    class << self
      def available?
        AppConfig.axiom[:master_key].present? && AppConfig.axiom[:dataset].present?
      end

      def summary(top: TOP_PARENTS_DEFAULT)
        return { available: false } unless available?

        dataset = AppConfig.axiom[:dataset]
        client = admin_client
        fields = client.list_fields(dataset: dataset)
        map_fields = safe_call { client.list_map_fields(dataset: dataset) } || []
        dataset_info = safe_call { client.dataset(id: dataset) }
        top_parents = compute_parent_distribution(fields, limit: top)

        {
          available: true,
          dataset: dataset,
          field_count: fields.size,
          field_limit: FIELD_LIMIT,
          headroom: FIELD_LIMIT - fields.size,
          last_refreshed_at: Time.current,
          top_parents: top_parents,
          map_fields: map_fields,
          dataset_info: dataset_info,
          map_field_set: Array(dataset_info&.dig("mapFields")).presence || map_fields
        }
      rescue Axiom::AdminClient::Error => e
        {
          available: true,
          error: e.message,
          error_status: e.status,
          error_body: e.body
        }
      end

      def datasets
        return [] unless AppConfig.axiom[:master_key].present?

        admin_client.datasets
      rescue StandardError
        []
      end

      def coerce_duration_param(value, fallback_hours: nil)
        str = value.to_s.strip.downcase
        str = nil if str.blank?

        if str.nil? && fallback_hours
          return format_duration_hours(fallback_hours)
        end

        return nil if str.nil?
        if str.match?(/\A\d+[smhdw]\z/)
          unit = str[-1]
          amount = str[0...-1].to_i
          case unit
          when "d"
            return format_duration_hours(amount * 24)
          when "w"
            return format_duration_hours(amount * 24 * 7)
          else
            return str
          end
        end

        if (match = str.match(/\A(\d+)([a-z]+)\z/))
          amount = match[1].to_i
          unit = match[2]
          hours = case unit
          when "d", "day", "days" then amount * 24
          when "h", "hour", "hours" then amount
          when "w", "week", "weeks" then amount * 24 * 7
          when "m", "min", "mins", "minute", "minutes" then (amount / 60.0)
          else
            nil
          end
          return format_duration_hours(hours) if hours
        elsif str.match?(/\A\d+\z/)
          return format_duration_hours(str.to_i)
        end

        nil
      end

      def admin_client
        Axiom::AdminClient.new(
          token: AppConfig.axiom[:master_key],
          base_url: AppConfig.axiom[:base_url]
        )
      end

      private

      def compute_parent_distribution(fields, limit:)
        counts = Hash.new(0)
        Array(fields).each do |field|
          name = field["name"] || field[:name]
          next unless name&.include?(".")

          parent = name.split(".")[0..-2].join(".")
          counts[parent] += 1
        end

        counts
          .sort_by { |(parent, count)| [ -count, parent ] }
          .first(limit)
          .map { |parent, count| { parent: parent, count: count } }
      end

      def safe_call
        yield
      rescue StandardError
        nil
      end

      def format_duration_hours(hours)
        return nil if hours.nil?
        if hours.is_a?(Float) && hours < 1
          seconds = (hours * 3600).round
          return "#{seconds}s"
        end
        "#{hours.to_i}h"
      end
    end
  end
end
