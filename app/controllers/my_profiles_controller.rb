class MyProfilesController < ApplicationController
  before_action :require_login
  before_action :load_profile_and_authorize, only: [ :settings, :regenerate, :destroy ]

  def index
    uid = current_user&.id || session[:current_user_id]
    if uid.blank?
      return redirect_to auth_github_path, alert: "Please sign in with GitHub"
    end
    @profiles = Profile.joins(:profile_ownerships).where(profile_ownerships: { user_id: uid }).order(:login)
  end

  def settings
    # @profile loaded by before_action
    @asset_og = @profile.profile_assets.find_by(kind: "og")
    @asset_card = @profile.profile_assets.find_by(kind: "card")
    @asset_simple = @profile.profile_assets.find_by(kind: "simple")
  end

  def regenerate
    # enqueue pipeline and mark queued
    Profiles::GeneratePipelineJob.perform_later(@profile.login)
    @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
    redirect_to my_profile_settings_path(username: @profile.login), notice: "Regeneration queued for @#{@profile.login}"
  end

  def destroy
    ownership = ProfileOwnership.find_by(user_id: current_user.id, profile_id: @profile.id)
    return redirect_to my_profiles_path, alert: "You do not own this profile" unless ownership
    ownership.destroy!
    redirect_to my_profiles_path, notice: "Removed @#{@profile.login} from your profiles"
  end

  private

  def require_login
    @current_user ||= User.find_by(id: session[:current_user_id]) if @current_user.nil? && session[:current_user_id].present?
    return if current_user.present?
    redirect_to auth_github_path, alert: "Please sign in with GitHub"
  end

  def load_profile_and_authorize
    @profile = Profile.for_login(params[:username]).first
    return redirect_to my_profiles_path, alert: "Profile not found" unless @profile
    owner_id = current_user&.id || session[:current_user_id]
    unless ProfileOwnership.exists?(user_id: owner_id, profile_id: @profile.id)
      redirect_to my_profiles_path, alert: "You do not own this profile"
    end
  end
end
