Rails.application.config.to_prepare do
  basic = (
    ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] ||
    (Rails.application.credentials.dig(:mission_control, :jobs, :http_basic) rescue nil)
  ).to_s

  next if basic.blank?

  user, pass = basic.split(":", 2).map { |s| s.to_s.strip }

  if defined?(MissionControl::Jobs::ApplicationController) && user.present? && pass.present?
    controller = MissionControl::Jobs::ApplicationController
    # Remove any previous basic auth to avoid duplicate/competing filters
    if controller.respond_to?(:skip_before_action)
      controller.skip_before_action(:authenticate_by_http_basic, raise: false)
    end
    controller.before_action do
      authenticate_or_request_with_http_basic("Mission Control") do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u.to_s, user) &&
          ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass)
      end
    end
  end
end
