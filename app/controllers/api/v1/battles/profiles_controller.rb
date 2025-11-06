module Api
  module V1
    module Battles
      class ProfilesController < ApplicationController
        # Frozen contract for TecHub Battles consumers.
        def card
          username = params[:username].to_s.downcase
          profile = Profile.for_login(username).first
          return render json: { error: "not_found" }, status: :not_found unless profile

          card = profile.profile_card
          return render json: { error: "no_card" }, status: :not_found unless card

          render json: {
            profile: {
              id: profile.id,
              login: profile.login,
              name: profile.name,
              avatar_url: profile.avatar_url
            },
            card: {
              archetype: card.archetype,
              spirit_animal: card.spirit_animal,
              attack: card.attack,
              defense: card.defense,
              speed: card.speed,
              vibe: card.vibe,
              vibe_description: card.vibe_description,
              special_move: card.special_move,
              special_move_description: card.special_move_description,
              buff: card.buff,
              buff_description: card.buff_description,
              weakness: card.weakness,
              weakness_description: card.weakness_description
            },
            activity: serialize_activity(profile.profile_activity)
          }
        end

        def battle_ready
          limit = (params[:limit] || 100).to_i
          profiles = Profile.includes(:profile_card)
                            .where.not(profile_cards: { id: nil })
                            .limit(limit)

          render json: {
            profiles: profiles.filter_map do |profile|
              card = profile.profile_card
              next unless card

              {
                profile: {
                  id: profile.id,
                  login: profile.login,
                  name: profile.name,
                  avatar_url: profile.avatar_url || "https://github.com/#{profile.login}.png"
                },
                card: {
                  archetype: card.archetype,
                  spirit_animal: card.spirit_animal,
                  attack: card.attack || 50,
                  defense: card.defense || 50,
                  speed: card.speed || 50,
                  vibe: card.vibe,
                  vibe_description: card.vibe_description,
                  special_move: card.special_move,
                  special_move_description: card.special_move_description,
                  buff: card.buff,
                  buff_description: card.buff_description,
                  weakness: card.weakness,
                  weakness_description: card.weakness_description
                },
                activity: serialize_activity(profile.profile_activity)
              }
            end
          }
        end

        private

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
      end
    end
  end
end
