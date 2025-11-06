module Api
  module V1
    class ProfilesController < ApplicationController
      # Read-only public JSON endpoint for a profile's generated assets
      # Example: GET /api/v1/profiles/loftwah/assets
      def assets
        username = params[:username].to_s.downcase
        profile = Profile.listed.for_login(username).first
        return render json: { error: "not_found" }, status: :not_found unless profile

        card = profile.profile_card
        assets = profile.profile_assets

        render json: {
          profile: {
            login: profile.login,
            display_name: (profile.name.presence || profile.login),
            updated_at: profile.updated_at
          },
          card: card && {
            title: card.title,
            tags: card.tags,
            archetype: card.archetype,
            spirit_animal: card.spirit_animal,
            avatar_choice: card.avatar_choice,
            bg_choices: {
              card: card.bg_choice_card,
              og: card.bg_choice_og,
              simple: card.bg_choice_simple
            }
          },
          assets: assets.map { |a| serialize_asset(a) }
        }
      end

      # GET /api/v1/profiles/:username
      # Returns profile card with battle stats (liquid contract)
      def show
        username = params[:username].to_s.downcase
        profile = Profile.listed.for_login(username).first
        return render json: { error: "not_found" }, status: :not_found unless profile

        card = profile.profile_card
        return render json: { error: "no_card" }, status: :not_found unless card

        render json: profile_payload(profile, card)
      end

      # GET /api/v1/profiles/battle-ready
      # Returns all profiles with cards (for battle selection)
      def battle_ready
        limit = (params[:limit] || 100).to_i
        profiles = Profile.listed.includes(:profile_card)
                         .where.not(profile_cards: { id: nil })
                         .limit(limit)

        render json: {
          profiles: profiles.filter_map do |profile|
            card = profile.profile_card
            next unless card # Skip if no card

            {
              profile: profile_summary(profile),
              card: card_stats(card, fallback: true),
              activity: serialize_activity(profile.profile_activity)
            }
          end
        }
      end

      private

      def serialize_asset(a)
        {
          kind: a.kind,
          public_url: a.public_url,
          mime_type: a.mime_type,
          width: a.width,
          height: a.height,
          provider: a.provider,
          updated_at: a.updated_at
        }
      end

      def serialize_activity(activity)
        return nil unless activity

        {
          score: activity.activity_score,
          total_events: activity.total_events,
          event_breakdown: activity.event_breakdown,
          recent_repos: activity.recent_repositories_list,
          last_active: activity.last_active,
          activity_metrics: activity.activity_metrics,
          current_streak: activity.activity_metric_value(:current_streak),
          longest_streak: activity.activity_metric_value(:longest_streak)
        }
      end

      def profile_payload(profile, card)
        {
          profile: profile_summary(profile),
          card: card_stats(card),
          activity: serialize_activity(profile.profile_activity)
        }
      end

      def profile_summary(profile)
        {
          id: profile.id,
          login: profile.login,
          name: profile.name,
          avatar_url: profile.avatar_url || "https://github.com/#{profile.login}.png"
        }
      end

      def card_stats(card, fallback: false)
        {
          archetype: card.archetype,
          spirit_animal: card.spirit_animal,
          attack: fallback ? (card.attack || 50) : card.attack,
          defense: fallback ? (card.defense || 50) : card.defense,
          speed: fallback ? (card.speed || 50) : card.speed,
          vibe: card.vibe,
          vibe_description: card.vibe_description,
          special_move: card.special_move,
          special_move_description: card.special_move_description,
          buff: card.buff,
          buff_description: card.buff_description,
          weakness: card.weakness,
          weakness_description: card.weakness_description
        }
      end
    end
  end
end
