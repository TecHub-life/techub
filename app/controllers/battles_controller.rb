class BattlesController < ApplicationController
  before_action :require_authentication, only: [:new, :create]

  def index
    @battles = Battle.includes(:challenger_profile, :opponent_profile, :winner_profile)
                     .completed
                     .recent
                     .limit(50)
  end

  def show
    @battle = Battle.includes(:challenger_profile, :opponent_profile, :winner_profile).find(params[:id])
    
    # If battle hasn't been simulated yet, simulate it now
    if @battle.battle_log.blank?
      result = Battles::SimulateService.call(
        challenger_id: @battle.challenger_profile_id,
        opponent_id: @battle.opponent_profile_id,
        battle: @battle
      )
      
      unless result.success?
        redirect_to battles_path, alert: "Battle simulation failed: #{result.error.message}"
        return
      end
      
      @battle.reload
    end
  end

  def new
    @profiles = Profile.includes(:profile_card)
                      .where.not(profile_cards: { id: nil })
                      .order(:login)
                      .limit(100)
  end

  def create
    # Create battle record without simulating
    @battle = Battle.create!(
      challenger_profile_id: params[:challenger_profile_id],
      opponent_profile_id: params[:opponent_profile_id]
    )
    
    redirect_to battle_path(@battle)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_battle_path, alert: "Failed to create battle: #{e.message}"
  end

  private

  def require_authentication
    unless current_user
      redirect_to login_path, alert: "You must be signed in to start a battle"
    end
  end
end
