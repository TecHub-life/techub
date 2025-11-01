module Api
  module V1
    class ProfilesController < ApplicationController
      # Read-only public JSON endpoint for a profile's card data including battle stats
      # Example: GET /api/v1/profiles/loftwah/card
      def card
        username = params[:username].to_s.downcase
        profile = Profile.for_login(username).first
        return render json: { error: "not_found" }, status: :not_found unless profile
        return render json: { error: "no_card" }, status: :not_found unless profile.profile_card

        card = profile.profile_card
        
        render json: {
          profile: {
            id: profile.id,
            login: profile.login,
            name: profile.name,
            avatar_url: profile.avatar_url,
            bio: profile.bio,
            location: profile.location,
            followers: profile.followers,
            updated_at: profile.updated_at
          },
          card: {
            title: card.title,
            vibe: card.vibe,
            archetype: card.archetype,
            spirit_animal: card.spirit_animal,
            attack: card.attack,
            defense: card.defense,
            speed: card.speed,
            tags: card.tags,
            special_moves: card.special_moves,
            playing_card: card.playing_card,
            avatar_choice: card.avatar_choice
          }
        }
      end

      # List all battle-ready profiles (have cards)
      # Example: GET /api/v1/profiles/battle-ready
      def battle_ready
        profiles = Profile.joins(:profile_card)
                         .includes(:profile_card)
                         .order(:login)
                         .limit(params[:limit] || 100)
        
        render json: {
          profiles: profiles.map do |profile|
            {
              id: profile.id,
              login: profile.login,
              name: profile.name,
              avatar_url: profile.avatar_url,
              card: {
                archetype: profile.profile_card.archetype,
                spirit_animal: profile.profile_card.spirit_animal,
                attack: profile.profile_card.attack,
                defense: profile.profile_card.defense,
                speed: profile.profile_card.speed
              }
            }
          end
        }
      end

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
