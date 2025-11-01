module Api
  module V1
    class BattlesController < BaseController
      def index
        @battles = Battle.includes(:challenger_profile, :opponent_profile, :winner_profile)
                         .completed
                         .recent
                         .limit(params[:limit] || 50)
        
        render json: @battles.map { |battle| battle_summary(battle) }
      end

      def show
        @battle = Battle.includes(:challenger_profile, :opponent_profile, :winner_profile).find(params[:id])
        
        render json: battle_detail(@battle)
      end

      def create
        result = Battles::SimulateService.call(
          challenger_id: params[:challenger_id],
          opponent_id: params[:opponent_id]
        )

        if result.success?
          render json: battle_detail(result.value), status: :created
        else
          render_error(result.error.message, status: :unprocessable_entity)
        end
      end

      private

      def battle_summary(battle)
        {
          id: battle.id,
          challenger: profile_summary(battle.challenger),
          opponent: profile_summary(battle.opponent),
          winner: profile_summary(battle.winner),
          challenger_hp: battle.challenger_hp,
          opponent_hp: battle.opponent_hp,
          status: battle.status,
          created_at: battle.created_at.iso8601,
          turns: battle.battle_log.count { |e| e["type"] == "attack" }
        }
      end

      def battle_detail(battle)
        {
          id: battle.id,
          challenger: profile_detail(battle.challenger),
          opponent: profile_detail(battle.opponent),
          winner: battle.winner ? profile_summary(battle.winner) : nil,
          challenger_hp: battle.challenger_hp,
          opponent_hp: battle.opponent_hp,
          status: battle.status,
          battle_log: battle.battle_log,
          metadata: battle.metadata,
          created_at: battle.created_at.iso8601,
          updated_at: battle.updated_at.iso8601
        }
      end

      def profile_summary(profile)
        return nil unless profile
        
        {
          id: profile.id,
          login: profile.login,
          name: profile.name,
          avatar_url: profile.avatar_url
        }
      end

      def profile_detail(profile)
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
            speed: profile.profile_card.speed,
            vibe: profile.profile_card.vibe
          }
        }
      end
    end
  end
end
