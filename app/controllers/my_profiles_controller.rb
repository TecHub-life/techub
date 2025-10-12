class MyProfilesController < ApplicationController
  before_action :require_login

  def index
    uid = current_user&.id || session[:current_user_id]
    if uid.blank?
      return redirect_to auth_github_path, alert: "Please sign in with GitHub"
    end
    @profiles = Profile.joins(:profile_ownerships).where(profile_ownerships: { user_id: uid }).order(:login)
  end

  def destroy
    profile = Profile.for_login(params[:username]).first
    unless profile
      return redirect_to my_profiles_path, alert: "Profile not found"
    end

    actor_id = current_user&.id || session[:current_user_id]
    ownership = ProfileOwnership.find_by(user_id: actor_id, profile_id: profile.id)
    unless ownership
      return redirect_to my_profiles_path, alert: "You do not own this profile"
    end

    ownership.destroy!
    redirect_to my_profiles_path, notice: "Removed @#{profile.login} from your profiles"
  end

  private

  def require_login
    @current_user ||= User.find_by(id: session[:current_user_id]) if @current_user.nil? && session[:current_user_id].present?
    return if current_user.present?
    redirect_to auth_github_path, alert: "Please sign in with GitHub"
  end
end
