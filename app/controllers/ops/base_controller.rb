module Ops
  class BaseController < ApplicationController
    before_action :require_ops_basic_auth

    private

    def require_ops_basic_auth
      cred = Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)
      basic = Rails.env.production? ? cred : (ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || cred)

      return head :forbidden if Rails.env.production? && basic.blank?

      if basic.present?
        authenticate_or_request_with_http_basic("Mission Control") do |u, p|
          user, pass = (basic.to_s.split(":", 2))
          ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) &
            ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
        end
      end
    end
  end
end
