if Rails.env.production?
  cred = Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)
  if cred.blank?
    Rails.logger.warn(message: "MISSION CONTROL JOBS HTTP BASIC missing in credentials; /ops/jobs will not be mounted")
  end
end
