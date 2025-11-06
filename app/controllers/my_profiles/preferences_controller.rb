module MyProfiles
  class PreferencesController < BaseController
    before_action :load_profile_and_authorize

    def update
      result = Profiles::Showcase::PreferenceUpdateService.call(profile: @profile, attributes: preference_params, actor: current_user)
      if result.success?
        redirect_to_settings(notice: "Preferences updated", tab: "styles")
      else
        redirect_to_settings(alert: result.error || "Unable to update preferences", tab: "styles")
      end
    end

    private

    def preference_params
      params.require(:preference).permit(
        :links_sort_mode,
        :achievements_sort_mode,
        :experiences_sort_mode,
        :default_style_variant,
        :default_style_accent,
        :default_style_shape,
        :achievements_date_format,
        :achievements_time_display,
        :achievements_dual_time,
        :pin_limit
      )
    end
  end
end
