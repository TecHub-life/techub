class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  class << self
    def get(key, default: nil)
      rec = find_by(key: key.to_s)
      rec ? rec.value : default
    end

    def set(key, value)
      rec = find_or_initialize_by(key: key.to_s)
      rec.value = value
      rec.save!
      rec.value
    end

    def get_json(key, default: nil)
      raw = get(key, default: nil)
      return default if raw.nil?
      JSON.parse(raw) rescue default
    end

    def set_json(key, value)
      set(key, value.to_json)
    end

    def get_bool(key, default: false)
      raw = get(key, default: nil)
      return default if raw.nil?
      %w[1 true yes on].include?(raw.to_s.downcase)
    end

    def set_bool(key, value)
      set(key, value ? "true" : "false")
    end
  end
end
