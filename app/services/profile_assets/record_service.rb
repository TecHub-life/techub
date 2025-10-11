module ProfileAssets
  class RecordService < ApplicationService
    def initialize(profile:, kind:, local_path:, public_url: nil, mime_type: nil, width: nil, height: nil, provider: nil)
      @profile = profile
      @kind = kind
      @local_path = local_path
      @public_url = public_url
      @mime_type = mime_type
      @width = width
      @height = height
      @provider = provider
    end

    def call
      return failure(StandardError.new("profile required")) unless profile.is_a?(Profile)
      return failure(StandardError.new("kind required")) if kind.to_s.blank?
      return failure(StandardError.new("local_path required")) if local_path.to_s.blank?

      record = profile.profile_assets.find_or_initialize_by(kind: kind)
      record.assign_attributes(
        local_path: local_path,
        public_url: public_url,
        mime_type: mime_type,
        width: width,
        height: height,
        provider: provider,
        generated_at: Time.current
      )
      if record.save
        success(record)
      else
        failure(StandardError.new("validation failed"), metadata: { errors: record.errors.full_messages })
      end
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :profile, :kind, :local_path, :public_url, :mime_type, :width, :height, :provider
  end
end
