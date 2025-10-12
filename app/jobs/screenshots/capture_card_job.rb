class Screenshots::CaptureCardJob < ApplicationJob
  queue_as :screenshots

  retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

  def perform(login:, variant: "og", host: nil)
    started = Time.current
    result = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
    unless result.success?
      StructuredLogger.error(message: "screenshot_failed", service: self.class.name, login: login, variant: variant, error: result.error&.message, metadata: result.metadata)
      raise result.error || StandardError.new("Screenshot failed")
    end

    profile = Profile.find_by(login: login)
    return unless profile

    rec = ProfileAssets::RecordService.call(
      profile: profile,
      kind: variant,
      local_path: result.value[:output_path],
      public_url: result.value[:public_url],
      mime_type: result.value[:mime_type],
      width: result.value[:width],
      height: result.value[:height],
      provider: "screenshot"
    )

    if rec.failure?
      StructuredLogger.warn(message: "record_asset_failed", service: self.class.name, login: login, variant: variant, error: rec.error&.message)
    else
      StructuredLogger.info(message: "record_asset_ok", service: self.class.name, login: login, variant: variant, public_url: rec.value.public_url, local_path: rec.value.local_path, duration_ms: ((Time.current - started) * 1000).to_i)
    end
  end
end
