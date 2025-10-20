module Profiles
  class GenerateSocialAssetsService < ApplicationService
    TARGETS = [
      # X (Twitter)
      { kind: "x_profile_400", width: 400, height: 400, src_kind: "avatar_1x1" },
      { kind: "x_header_1500x500", width: 1500, height: 500, src_kind: "avatar_3x1" },
      { kind: "x_feed_1600x900", width: 1600, height: 900, src_kind: "avatar_16x9" },
      # Instagram
      { kind: "ig_square_1080", width: 1080, height: 1080, src_kind: "avatar_1x1" },
      { kind: "ig_portrait_1080x1350", width: 1080, height: 1350, src_kind: "avatar_9x16" },
      { kind: "ig_landscape_1080x566", width: 1080, height: 566, src_kind: "avatar_16x9" },
      # Facebook
      { kind: "fb_cover_851x315", width: 851, height: 315, src_kind: "avatar_16x9" },
      { kind: "fb_post_1080", width: 1080, height: 1080, src_kind: "avatar_1x1" },
      # LinkedIn
      { kind: "linkedin_cover_1584x396", width: 1584, height: 396, src_kind: "avatar_3x1" },
      { kind: "linkedin_profile_400", width: 400, height: 400, src_kind: "avatar_1x1" },
      # YouTube
      { kind: "youtube_cover_2560x1440", width: 2560, height: 1440, src_kind: "avatar_16x9" },
      # OpenGraph (generic)
      { kind: "og_1200x630", width: 1200, height: 630, src_kind: "avatar_16x9" }
    ].freeze

    def initialize(login:, upload: false)
      @login = login.to_s.downcase
      @upload = upload
    end

    def call
      profile = Profile.for_login(login).first
      return failure(StandardError.new("Profile not found"), metadata: { login: login }) unless profile

      base_dir = Rails.root.join("public", "generated", login)
      FileUtils.mkdir_p(base_dir)

      produced = []
      TARGETS.each do |t|
        src = find_source_asset(profile, t[:src_kind], base_dir)
        next unless src

        out = base_dir.join(output_filename_for(t[:kind]))
        resized = Images::ResizeService.call(src_path: src, output_path: out, width: t[:width], height: t[:height], fit: "cover")
        next unless resized.success?

        public_url = nil
        if upload_enabled? && upload
          up = Storage::ActiveStorageUploadService.call(path: resized.value[:output_path], content_type: "image/jpeg", filename: File.basename(out))
          public_url = up.success? ? up.value[:public_url] : nil
        end

        ProfileAssets::RecordService.call(
          profile: profile,
          kind: t[:kind],
          local_path: resized.value[:output_path],
          public_url: public_url,
          mime_type: "image/jpeg",
          width: t[:width],
          height: t[:height],
          provider: "postprocess"
        )

        produced << { kind: t[:kind], path: resized.value[:output_path], public_url: public_url }
      end

      success({ login: login, produced: produced })
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :login, :upload

    def find_source_asset(profile, src_kind, base_dir)
      rec = profile.profile_assets.find_by(kind: src_kind)
      return rec.public_url if rec&.public_url.present?

      candidates = {
        "avatar_1x1" => [ base_dir.join("avatar-1x1.jpg"), base_dir.join("avatar-1x1.png") ],
        "avatar_3x1" => [ base_dir.join("avatar-3x1.jpg"), base_dir.join("avatar-3x1.png") ],
        "avatar_16x9" => [ base_dir.join("avatar-16x9.jpg"), base_dir.join("avatar-16x9.png") ],
        "avatar_9x16" => [ base_dir.join("avatar-9x16.jpg"), base_dir.join("avatar-9x16.png") ]
      }[src_kind] || []

      file = candidates.find { |p| File.exist?(p) }
      file&.to_s
    end

    def output_filename_for(kind)
      case kind
      when "x_profile_400" then "x-profile-400x400.jpg"
      when "x_header_1500x500" then "x-header-1500x500.jpg"
      when "x_feed_1600x900" then "x-feed-1600x900.jpg"
      when "ig_square_1080" then "ig-square-1080.jpg"
      when "ig_portrait_1080x1350" then "ig-portrait-1080x1350.jpg"
      when "ig_landscape_1080x566" then "ig-landscape-1080x566.jpg"
      when "fb_cover_851x315" then "fb-cover-851x315.jpg"
      when "fb_post_1080" then "fb-post-1080x1080.jpg"
      when "linkedin_cover_1584x396" then "linkedin-cover-1584x396.jpg"
      when "linkedin_profile_400" then "linkedin-profile-400x400.jpg"
      when "youtube_cover_2560x1440" then "youtube-cover-2560x1440.jpg"
      when "og_1200x630" then "og-1200x630.jpg"
      else
        "#{kind}.jpg"
      end
    end

    def upload_enabled?
      flag = ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase
      [ "1", "true", "yes" ].include?(flag) || Rails.env.production?
    end
  end
end
