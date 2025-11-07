module MyProfiles
  class BaseController < ApplicationController
    before_action :require_login

    private

    def require_login
      @current_user ||= User.find_by(id: session[:current_user_id]) if @current_user.nil? && session[:current_user_id].present?
      return if current_user.present?

      redirect_to auth_github_path, alert: "Please sign in with GitHub"
    end

    def load_profile_and_authorize
      @profile = Profile.for_login(params[:username]).first
      return redirect_to(my_profiles_path, alert: "Profile not found") unless @profile

      owner_id = current_user&.id || session[:current_user_id]
      unless ProfileOwnership.exists?(user_id: owner_id, profile_id: @profile.id)
        redirect_to(my_profiles_path, alert: "You do not own this profile")
      end
    end

    def redirect_to_settings(notice: nil, alert: nil, tab: nil)
      flash_opts = {}
      flash_opts[:notice] = notice if notice.present?
      flash_opts[:alert] = alert if alert.present?

      target_path = settings_path_with_tab(tab)
      return redirect_to(target_path) if flash_opts.empty?

      redirect_to(target_path, flash_opts)
    end

    def settings_path_with_tab(tab)
      tab_name = tab.presence || params[:tab].presence
      path_args = { username: @profile.login }
      path_args[:tab] = tab_name if tab_name.present?
      anchor = tab_name.present? ? "tab-#{tab_name}" : nil
      path_args[:anchor] = anchor if anchor
      my_profile_settings_path(path_args)
    end
  end
end
