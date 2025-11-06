class AnalyticsController < ApplicationController

  def showcase
    payload = showcase_params.to_h.symbolize_keys
    Analytics::ProfileShowcaseTracker.call(
      attributes: payload,
      user: current_user,
      visit_token: respond_to?(:ahoy) ? ahoy.visit_token : nil
    )
    head :ok
  rescue ActionController::ParameterMissing
    head :ok
  end

  private

  def showcase_params
    params.require(:event)
    params.permit(:event, :profile, :item_id, :kind, :pinned, :hidden, :style, :surface)
  end
end
