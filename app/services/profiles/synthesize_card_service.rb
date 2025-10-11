module Profiles
  class SynthesizeCardService < ApplicationService
    DEFAULT_STYLE = if defined?(Gemini::AvatarPromptService) && Gemini::AvatarPromptService.const_defined?(:DEFAULT_STYLE_PROFILE)
      Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE
    else
      "neon-lit anime portrait"
    end

    def initialize(profile:, persist: true, theme: "TecHub")
      @profile = profile
      @persist = persist
      @theme = theme
    end

    def call
      return failure(StandardError.new("profile is required")) unless profile.is_a?(Profile)

      attrs = compute_from_signals(profile)

      if persist
        record = profile.profile_card || profile.build_profile_card
        record.assign_attributes(attrs.merge(generated_at: Time.current))
        if record.save
          success(record)
        else
          failure(StandardError.new("validation failed"), metadata: { errors: record.errors.full_messages })
        end
      else
        success(attrs)
      end
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :profile, :persist, :theme

    def compute_from_signals(p)
      followers = p.followers.to_i
      public_repos = p.public_repos.to_i
      orgs = p.profile_organizations.size
      events = p.profile_activity&.total_events.to_i

      top_repos = Array(p.top_repositories).first(3)
      stars = top_repos.sum { |r| r.stargazers_count.to_i }
      active_count = Array(p.active_repositories).size

      attack = clamp((followers / 10.0) + (stars / 50.0) + (active_count * 5.0))
      defense = clamp((account_age_years(p) * 8.0) + (orgs * 6.0) + (public_repos / 10.0))
      speed = clamp((events / 5.0) + (active_count * 4.0))

      dominant_lang = p.profile_languages.order(count: :desc).first&.name.to_s
      spirit_animal = spirit_for_language(dominant_lang)

      tags = p.profile_languages.order(count: :desc).limit(5).pluck(:name)
      tags += top_repos.map(&:name)

      tagline_source = p.summary.to_s
      tagline_source = p.bio.to_s if tagline_source.blank?

      {
        title: p.display_name,
        tagline: tagline_source.truncate(80),
        attack: attack,
        defense: defense,
        speed: speed,
        vibe: vibe_from_bio(p.bio),
        special_move: special_move_from_profile(p),
        spirit_animal: spirit_animal,
        archetype: archetype_from_signals(p),
        tags: tags.uniq.first(8),
        style_profile: DEFAULT_STYLE,
        theme: theme
      }
    end

    def clamp(n)
      [ [ n.round, 0 ].max, 100 ].min
    end

    def account_age_years(p)
      created = p.github_created_at || Time.current
      ((Time.current - created) / 1.year).floor
    end

    def spirit_for_language(lang)
      case lang.to_s.downcase
      when "ruby" then "Red Panda"
      when "javascript", "typescript" then "Hummingbird"
      when "go" then "Falcon"
      when "python" then "Snow Leopard"
      else "Fox"
      end
    end

    def vibe_from_bio(bio)
      s = bio.to_s.downcase
      return "Open Source" if s.include?("oss") || s.include?("open source")
      return "Founder" if s.include?("founder") || s.include?("startup")
      return "AI Builder" if s.include?("ai") || s.include?("ml")
      "Builder"
    end

    def special_move_from_profile(p)
      if p.top_repositories.any? { |r| r.stargazers_count.to_i > 1000 }
        "Starfall Combo"
      elsif p.followers.to_i > 1000
        "Community Rally"
      else
        "Refactor Surge"
      end
    end

    def archetype_from_signals(p)
      if p.profile_organizations.size > 3
        "Guild Leader"
      elsif p.public_repos.to_i > 50
        "Archivist"
      else
        "Sprinter"
      end
    end
  end
end
