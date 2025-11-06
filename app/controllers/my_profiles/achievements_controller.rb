module MyProfiles
  class AchievementsController < BaseController
    before_action :load_profile_and_authorize
    before_action :set_achievement, only: [ :update, :destroy ]

    def create
      result = Profiles::Showcase::AchievementUpsertService.call(profile: @profile, achievement: nil, attributes: achievement_params, actor: current_user)
      handle_result(result, success: "Achievement added")
    end

    def update
      result = Profiles::Showcase::AchievementUpsertService.call(profile: @profile, achievement: @achievement, attributes: achievement_params, actor: current_user)
      handle_result(result, success: "Achievement updated")
    end

    def destroy
      if @achievement.destroy
        handle_result(ServiceResult.success(nil), success: "Achievement removed")
      else
        handle_result(ServiceResult.failure(@achievement.errors.full_messages.to_sentence))
      end
    end

    private

    def set_achievement
      @achievement = @profile.profile_achievements.find(params[:id])
    end

    def achievement_params
      params.require(:achievement).permit(
        :title,
        :description,
        :url,
        :fa_icon,
        :occurred_at,
        :occurred_on,
        :timezone,
        :date_display_mode,
        :active,
        :hidden,
        :pinned,
        :pin_surface,
        :pin_position,
        :position,
        :style_variant,
        :style_accent,
        :style_shape
      )
    end

    def handle_result(result, success: "Saved")
      if result.success?
          redirect_to_settings(notice: success, tab: "showcase")
      else
          redirect_to_settings(alert: result.error || "Unable to save achievement", tab: "showcase")
      end
    end
  end
end
