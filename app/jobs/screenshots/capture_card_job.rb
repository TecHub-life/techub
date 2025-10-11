class Screenshots::CaptureCardJob < ApplicationJob
  queue_as :screenshots

  def perform(login:, variant: "og", host: nil)
    result = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
    unless result.success?
      StructuredLogger.error(message: "Screenshot failed", service: self.class.name, login: login, variant: variant, error: result.error&.message, metadata: result.metadata)
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
      StructuredLogger.warn(message: "Recorded asset failed", service: self.class.name, login: login, variant: variant, error: rec.error&.message)
    else
      StructuredLogger.info(message: "Recorded asset", service: self.class.name, login: login, variant: variant, public_url: rec.value.public_url, local_path: rec.value.local_path)
    end
  end
end
