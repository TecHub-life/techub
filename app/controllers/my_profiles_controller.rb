class MyProfilesController < ApplicationController
  before_action :require_login

  def index
    @profiles = current_user.profiles.order(:login)
  end

  def destroy
    profile = Profile.for_login(params[:username]).first
    unless profile
      return redirect_to my_profiles_path, alert: "Profile not found"
    end

    ownership = current_user.profile_ownerships.find_by(profile_id: profile.id)
    unless ownership
      return redirect_to my_profiles_path, alert: "You do not own this profile"
    end

    ownership.destroy!
    redirect_to my_profiles_path, notice: "Removed @#{profile.login} from your profiles"
  end

  private

  def require_login
    return if current_user.present?
    redirect_to auth_github_path, alert: "Please sign in with GitHub"
  end
end
