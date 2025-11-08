module Profiles
  class SynthesizeCardService < ApplicationService
    DEFAULT_STYLE = if defined?(Avatars::AvatarPromptService) && Avatars::AvatarPromptService.const_defined?(:DEFAULT_STYLE_PROFILE)
      Avatars::AvatarPromptService::DEFAULT_STYLE_PROFILE
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
      # Apply account-level overrides (e.g., Loftwah)
      begin
        acct_overrides = Profiles::AiOverrides.for(profile)
        attrs.merge!(acct_overrides) if acct_overrides.present?
      rescue NameError
        # ignore if overrides module not loaded
      end

      if persist
        # Concurrency-safe create-or-find to respect unique index on profile_id
        begin
          record = ProfileCard.find_or_create_by(profile_id: profile.id) do |card|
            # Set default values when creating
            card.title = profile.display_name
            card.attack = 70
            card.defense = 60
            card.speed = 80
            card.tags = %w[coder developer maker builder engineer hacker]
          end
        rescue ActiveRecord::RecordNotUnique
          # Race condition: another job created the card between find and create
          # Just reload and use the existing one
          record = ProfileCard.find_by!(profile_id: profile.id)
        end

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

      # Tags: six, lowercase, relevant
      tags = []
      # 1) Top languages (up to 3)
      tags += p.profile_languages.order(count: :desc).limit(3).pluck(:name)
      # 2) Popular repository topics across this profile (up to 3)
      topic_counts = Hash.new(0)
      owners = Array(p.organization_logins) + [ p.login ]
      Array(p.profile_repositories).each do |r|
        owner = (r.full_name.to_s.split("/").first.presence || p.login).downcase
        next unless owners.map(&:downcase).include?(owner)
        Array(r.topics_list).each { |t| topic_counts[t] += 1 }
      end
      popular_topics = topic_counts.sort_by { |(_t, c)| -c }.map(&:first).first(3)
      tags += popular_topics
      # 3) Role/descriptor from signals (1 slot if room)
      role = case vibe_from_bio(p.bio)
      when "Open Source" then "open-source"
      when "Founder" then "founder"
      when "AI Builder" then "ai"
      else "builder"
      end
      tags << role
      # Normalize: lowercase, uniq, drop blanks
      tags = tags.map { |t| t.to_s.strip.downcase }.reject(&:blank?).uniq
      # Ensure exactly 6 tags to satisfy model validation
      fallback_pool = %w[developer coder builder maker engineer hacker]
      fallback_cycle = fallback_pool.cycle
      while tags.length < 6
        candidate = fallback_cycle.next
        tags << candidate unless tags.include?(candidate)
      end
      tags = tags.first(6)

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
        playing_card: playing_card_from_signals(p),
        tags: tags,
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
      when "ruby" then "Wombat"
      when "javascript", "typescript" then "Kookaburra"
      when "go" then "Emu"
      when "python" then "Platypus"
      else "Quokka"
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
        "The Ruler"
      elsif p.public_repos.to_i > 50
        "The Sage"
      else
        "The Explorer"
      end
    end

    def playing_card_from_signals(p)
      # Suit by dominant language family, rank by followers/stars bracket
      lang = p.profile_languages.order(count: :desc).first&.name.to_s.downcase
      suit = case lang
      when /ruby|rails/ then "♥"
      when /js|ts|node/ then "♣"
      when /go/ then "♠"
      when /python/ then "♦"
      else [ "♣", "♦", "♥", "♠" ][p.login.to_s.hash % 4]
      end

      star_sum = Array(p.top_repositories).first(5).sum { |r| r.stargazers_count.to_i }
      score = (p.followers.to_i / 250) + (star_sum / 1000)
      rank = case score
      when 8.. then "Ace"
      when 6..7 then "King"
      when 4..5 then "Queen"
      when 2..3 then "Jack"
      else [ "10", "9", "8", "7" ][p.public_repos.to_i % 4]
      end

      "#{rank} of #{suit}"
    end
  end
end
