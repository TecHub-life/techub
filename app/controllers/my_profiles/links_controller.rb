module MyProfiles
  class LinksController < BaseController
    before_action :load_profile_and_authorize
    before_action :set_link, only: [ :update, :destroy ]

    def create
      result = Profiles::Showcase::LinkUpsertService.call(profile: @profile, attributes: link_params, actor: current_user)
      handle_result(result, success: "Link added")
    end

    def update
      result = Profiles::Showcase::LinkUpsertService.call(profile: @profile, link: @link, attributes: link_params, actor: current_user)
      handle_result(result, success: "Link updated")
    end

    def destroy
      if @link.destroy
        handle_result(ServiceResult.success(nil), success: "Link removed")
      else
        handle_result(ServiceResult.failure(@link.errors.full_messages.to_sentence))
      end
    end

    private

    def set_link
      @link = @profile.profile_links.find(params[:id])
    end

    def link_params
      params.require(:link).permit(
        :label,
        :subtitle,
        :url,
        :fa_icon,
        :active,
        :hidden,
        :pinned,
        :pin_surface,
        :pin_position,
        :position,
        :style_variant,
        :style_accent,
        :style_shape,
        :secret_code
      )
    end

    def handle_result(result, success: "Saved")
      if result.success?
        redirect_to_settings(notice: success, tab: "showcase")
      else
        redirect_to_settings(alert: result.error || "Unable to save", tab: "showcase")
      end
    end
  end
end
