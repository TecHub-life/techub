module MyProfiles
  class ExperiencesController < BaseController
    before_action :load_profile_and_authorize
    before_action :set_experience, only: [ :update, :destroy ]

    def create
      result = Profiles::Showcase::ExperienceUpsertService.call(profile: @profile, experience: nil, attributes: experience_params, actor: current_user)
      handle_result(result, success: "Experience added")
    end

    def update
      result = Profiles::Showcase::ExperienceUpsertService.call(profile: @profile, experience: @experience, attributes: experience_params, actor: current_user)
      handle_result(result, success: "Experience updated")
    end

    def destroy
      if @experience.destroy
        handle_result(ServiceResult.success(nil), success: "Experience removed")
      else
        handle_result(ServiceResult.failure(@experience.errors.full_messages.to_sentence))
      end
    end

    private

    def set_experience
      @experience = @profile.profile_experiences.find(params[:id])
    end

    def experience_params
      params.require(:experience).permit(
        :title,
        :employment_type,
        :organization,
        :organization_url,
        :current_role,
        :started_on,
        :ended_on,
        :location,
        :location_type,
        :location_timezone,
        :description,
        :active,
        :hidden,
        :pinned,
        :pin_surface,
        :pin_position,
        :position,
        :style_variant,
        :style_accent,
        :style_shape,
        :skills_text
      )
    end

    def handle_result(result, success: "Saved")
      if result.success?
        redirect_to_settings(notice: success, tab: "showcase")
      else
        redirect_to_settings(alert: result.error || "Unable to save experience", tab: "showcase")
      end
    end
  end
end
