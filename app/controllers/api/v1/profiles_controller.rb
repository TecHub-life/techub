module Api
  module V1
    class ProfilesController < ApplicationController
      # Read-only public JSON endpoint for a profile's generated assets
      # Example: GET /api/v1/profiles/loftwah/assets
      def assets
        username = params[:username].to_s.downcase
        profile = Profile.for_login(username).first
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

      # GET /api/v1/profiles/:username/card
      # Returns profile card with battle stats
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
            special_move: card.special_move
          }
        }
      end

      # GET /api/v1/profiles/battle-ready
      # Returns all profiles with cards (for battle selection)
      def battle_ready
        limit = (params[:limit] || 100).to_i
        profiles = Profile.includes(:profile_card)
                         .where.not(profile_cards: { id: nil })
                         .limit(limit)

        render json: {
          profiles: profiles.filter_map do |profile|
            card = profile.profile_card
            next unless card # Skip if no card

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
                special_move: card.special_move
              }
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
    end
  end
end
