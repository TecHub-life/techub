module Gemini
  class AvatarImageSuiteService < ApplicationService
    VARIANTS = {
      "1x1" => { aspect_ratio: "1:1", filename: "avatar-1x1.png" },
      "16x9" => { aspect_ratio: "16:9", filename: "avatar-16x9.png" },
      "3x1" => { aspect_ratio: "3:1", filename: "avatar-3x1.png" },
      "9x16" => { aspect_ratio: "9:16", filename: "avatar-9x16.png" }
    }.freeze

    def initialize(
      login:,
      avatar_path: nil,
      output_dir: Rails.root.join("public", "generated"),
      prompt_theme: "TecHub",
      style_profile: AvatarPromptService::DEFAULT_STYLE_PROFILE,
      prompt_service: AvatarPromptService,
      image_service: ImageGenerationService,
      provider: nil,
      filename_suffix: nil,
      eligibility_service: Eligibility::GithubProfileScoreService,
      require_profile_eligibility: false,
      eligibility_threshold: Eligibility::GithubProfileScoreService::DEFAULT_THRESHOLD
    )
      @login = login
      @avatar_path = avatar_path
      @output_dir = Pathname.new(output_dir)
      @prompt_theme = prompt_theme
      @style_profile = style_profile
      @prompt_service = prompt_service
      @image_service = image_service
      @provider_override = provider
      @filename_suffix = filename_suffix
      @eligibility_service = eligibility_service
      @require_profile_eligibility = require_profile_eligibility
      @eligibility_threshold = eligibility_threshold
    end

    def call
      description_path = source_avatar_path
      return failure(StandardError.new("Avatar image not found for #{login}"), metadata: { expected_path: description_path.to_s }) unless File.exist?(description_path)

      if require_profile_eligibility
        profile_record = find_profile_record(login)
        return failure(StandardError.new("Profile not found for #{login}"), metadata: { login: login }) unless profile_record

        eligibility_payload = build_eligibility_payload(profile_record)
        eligibility_result = eligibility_service.call(**eligibility_payload.merge(threshold: eligibility_threshold))
        if eligibility_result.failure? || !eligibility_result.value[:eligible]
          return failure(StandardError.new("Profile not eligible for generation"), metadata: { login: login, eligibility: eligibility_result.value })
        end
      end

      prompts_result = prompt_service.call(
        avatar_path: description_path,
        prompt_theme: prompt_theme,
        style_profile: style_profile,
        provider: provider_override,
        profile_context: profile_context_for(login)
      )
      return prompts_result if prompts_result.failure?

      description = prompts_result.value[:avatar_description]
      structured = prompts_result.value[:structured_description]
      prompts = (prompts_result.value[:image_prompts] || {}).dup
      provider_for_artifacts = (prompts_result.metadata || {})[:provider] || provider_override

      generated = {}

      VARIANTS.each do |key, variant|
        prompt = prompts[key]
        unless prompt.present?
          return failure(StandardError.new("Missing prompt for #{key} variant"), metadata: { prompts: prompts.keys })
        end

        variant_output_path = output_dir.join(login, filename_with_suffix(variant[:filename]))
        result = image_service.call(
          prompt: prompt,
          aspect_ratio: variant[:aspect_ratio],
          output_path: variant_output_path,
          provider: provider_override
        )
        return result if result.failure?

        payload = result.value.merge(aspect_ratio: variant[:aspect_ratio])

        # Convert to JPEG for smaller size by default (progressive via vips)
        begin
          src_path = payload[:output_path]
          jpg_path = src_path.to_s.sub(/\.png\z/i, ".jpg")
          conv = Images::OptimizeService.call(path: src_path, output_path: jpg_path, format: "jpg", quality: 85)
          if conv.success?
            # Optionally remove original PNG to save space
            FileUtils.rm_f(src_path) if src_path.to_s.casecmp(jpg_path) != 0
            payload[:output_path] = conv.value[:output_path]
            payload[:mime_type] = "image/jpeg"
          end
        rescue StandardError
          # If conversion fails, keep original PNG
        end

        if upload_enabled?
          begin
            out_path = payload[:output_path].to_s
            if out_path.strip.empty? || !File.exist?(out_path)
              StructuredLogger.warn(message: "avatar_upload_skipped_missing_path", login: login, path: out_path) if defined?(StructuredLogger)
            else
              upload = Storage::ActiveStorageUploadService.call(
                path: out_path,
                content_type: payload[:mime_type],
                filename: File.basename(out_path)
              )
              if upload.success?
                payload[:public_url] = upload.value[:public_url]
              else
                StructuredLogger.warn(message: "avatar_upload_failed", login: login, error: upload.error&.message, path: out_path) if defined?(StructuredLogger)
                # continue without public_url
              end
            end
          rescue StandardError => e
            StructuredLogger.warn(message: "avatar_upload_exception", login: login, error: e.message) if defined?(StructuredLogger)
          end
        end

        generated[key] = payload

        # Record assets for later lookup (unified storage for URLs)
        begin
          record_variant_asset(
            kind: variant_kind(key),
            local_path: payload[:output_path],
            public_url: payload[:public_url],
            mime_type: payload[:mime_type],
            provider: provider_for_artifacts
          )
        rescue StandardError
          # best-effort; ignore recording failures
        end

        # Enqueue background optimization for large generated assets (best-effort)
        begin
          threshold = (ENV["IMAGE_OPT_BG_THRESHOLD"] || 300_000).to_i
          file_size = File.size(payload[:output_path]) rescue 0
          if file_size >= threshold
            Images::OptimizeJob.perform_later(
              path: payload[:output_path],
              login: login,
              kind: variant_kind(key),
              format: nil,
              quality: nil,
              min_bytes_for_bg: threshold,
              upload: upload_enabled?
            )
          end
        rescue StandardError
          # ignore enqueue failures
        end
      end

      # Best-effort: persist prompts + metadata artifacts next to outputs
      write_artifacts(
        provider_for_artifacts,
        description: description,
        structured: structured,
        prompts: prompts,
        metadata: prompts_result.metadata
      )

      success(
        {
          login: login,
          avatar_description: description,
          structured_description: structured,
          prompts: prompts,
          images: generated,
          output_dir: output_dir.join(login).to_s
        },
        metadata: prompts_result.metadata
      )
    end

    private

    attr_reader :login, :avatar_path, :output_dir, :prompt_theme, :style_profile, :prompt_service, :image_service, :provider_override, :filename_suffix, :eligibility_service, :require_profile_eligibility, :eligibility_threshold

    def source_avatar_path
      return Pathname.new(avatar_path) if avatar_path.present?

      Rails.root.join("public", "avatars", "#{login}.png")
    end

    def profile_context_for(login)
      record = Profile
        .includes(:profile_organizations, :profile_social_accounts, :profile_languages, :profile_activity, profile_repositories: :repository_topics)
        .find_by(login: login.downcase) rescue nil
      return {} unless record

      followers_band = format_followers(record.followers)
      tenure_years = compute_tenure_years(record.github_created_at || record.created_at)
      activity_level = compute_activity_level(record.profile_activity)
      topics = dominant_topics(record, limit: 2)

      {
        name: record.respond_to?(:name) ? (record.name.presence || record.login) : record.login,
        summary: record.respond_to?(:summary) ? record.summary.to_s.strip : "",
        languages: fetch_names(record, :profile_languages, :name, limit: 5),
        top_repositories: fetch_repo_names(record),
        organizations: fetch_org_names(record),
        followers_band: followers_band,
        tenure_years: tenure_years,
        activity_level: activity_level,
        topics: topics,
        hireable: !!record.hireable
      }
    end

    def find_profile_record(login)
      Profile.includes(:profile_repositories, :profile_organizations, :profile_readme, :profile_activity, :profile_languages, :profile_social_accounts)
        .find_by(login: login.downcase) rescue nil
    end

    def build_eligibility_payload(record)
      profile_hash = {
        login: record.login,
        created_at: (record.github_created_at || record.created_at),
        followers: record.followers,
        following: record.following,
        bio: record.bio
      }

      repositories = Array(record.profile_repositories).map do |repo|
        owner_login = if repo.respond_to?(:full_name) && repo.full_name.present?
          repo.full_name.to_s.split("/").first
        else
          record.login
        end

        {
          name: repo.name,
          full_name: repo.full_name || [ owner_login, repo.name ].compact.join("/"),
          pushed_at: (repo.github_updated_at || repo.updated_at),
          private: false,
          archived: false,
          owner: { login: owner_login }
        }
      end

      pinned_repositories = Array(record.pinned_repositories).map { |r| { name: r.name } }
      organizations = Array(record.profile_organizations).map { |o| { login: o.login } }
      recent_activity = { total_events: record.profile_activity&.total_events.to_i }
      profile_readme = record.profile_readme&.content

      {
        profile: profile_hash,
        repositories: repositories,
        recent_activity: recent_activity,
        pinned_repositories: pinned_repositories,
        profile_readme: profile_readme,
        organizations: organizations,
        as_of: Time.current
      }
    end

    def fetch_names(record, assoc, field, limit: 3)
      collection = record.respond_to?(assoc) ? record.public_send(assoc) : []
      if collection.respond_to?(:limit)
        collection.limit(limit).pluck(field)
      else
        Array(collection).first(limit).map { |o| o.respond_to?(field) ? o.public_send(field) : nil }.compact
      end
    end

    def fetch_repo_names(record)
      collection = record.respond_to?(:profile_repositories) ? record.profile_repositories : []
      if collection.respond_to?(:where)
        collection.where(repository_type: "top").order(stargazers_count: :desc).limit(3).pluck(:name)
      else
        Array(collection)
          .select { |repo| repo.respond_to?(:repository_type) ? repo.repository_type == "top" : true }
          .first(3)
          .map { |repo| repo.respond_to?(:name) ? repo.name : nil }
          .compact
      end
    end

    def fetch_org_names(record)
      collection = record.respond_to?(:profile_organizations) ? record.profile_organizations : []
      if collection.respond_to?(:limit)
        collection.limit(3).pluck(:name, :login).map { |name, login| name.presence || login }
      else
        Array(collection).first(3).map { |org| org.respond_to?(:name) ? (org.name.presence || (org.respond_to?(:login) ? org.login : nil)) : nil }.compact
      end
    end

    def dominant_topics(record, limit: 2)
      counts = Hash.new(0)
      owners = Array(record.organization_logins) + [ record.login ]
      Array(record.profile_repositories).each do |repo|
        owner = (repo.full_name.to_s.split("/").first.presence || record.login).downcase
        next unless owners.map(&:downcase).include?(owner)
        Array(repo.repository_topics).each { |t| counts[t.name.to_s.downcase] += 1 }
      end
      counts.sort_by { |(_t, c)| -c }.map(&:first).first(limit)
    end

    def compute_tenure_years(created_at)
      return nil unless created_at
      years = ((Time.current - created_at.to_time) / 1.year).floor
      [ years, 0 ].max
    end

    def compute_activity_level(activity)
      return nil unless activity
      total = activity.total_events.to_i
      case total
      when 60.. then "high"
      when 20..59 then "medium"
      else "low"
      end
    end

    def format_followers(n)
      n = n.to_i
      return "0" if n <= 0
      return sprintf("%.1fk", n / 1000.0) if n >= 1000
      n.to_s
    end

    def filename_with_suffix(filename)
      return filename unless filename_suffix.to_s.strip.present?

      base = File.basename(filename, File.extname(filename))
      ext = File.extname(filename)
      "#{base}-#{filename_suffix}#{ext}"
    end

    def upload_enabled?
      flag = ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase
      env_enabled = [ "1", "true", "yes" ].include?(flag)
      env_enabled || Rails.env.production?
    end

    def record_variant_asset(kind:, local_path:, public_url:, mime_type:, provider: nil)
      profile = Profile.find_by(login: login.downcase) rescue nil
      return unless profile

      ProfileAssets::RecordService.call(
        profile: profile,
        kind: kind,
        local_path: local_path,
        public_url: public_url,
        mime_type: mime_type,
        provider: provider
      )
    rescue StandardError
      # best-effort; do not fail generation due to asset record
    end

    def variant_kind(key)
      case key.to_s
      when "1x1" then "avatar_1x1"
      when "16x9" then "avatar_16x9"
      when "3x1" then "avatar_3x1"
      when "9x16" then "avatar_9x16"
      else key.to_s
      end
    end

    # Persist prompts and metadata artifacts for auditability
    def write_artifacts(provider, description:, structured:, prompts:, metadata: {})
      provider_key = provider.to_s.strip.presence || "unknown"
      base_dir = output_dir.join(login, "meta")
      FileUtils.mkdir_p(base_dir)

      prompts_payload = {
        avatar_description: description,
        structured_description: structured,
        prompts: prompts
      }

      meta_payload = metadata || {}

      File.write(base_dir.join("prompts-#{provider_key}.json"), JSON.pretty_generate(prompts_payload))
      File.write(base_dir.join("meta-#{provider_key}.json"), JSON.pretty_generate(meta_payload))
    rescue StandardError => e
      # Best-effort; do not fail generation due to artifact write
      StructuredLogger.warn(message: "Failed to write artifacts", login: login, provider: provider_key, error: e.message) if defined?(StructuredLogger)
    end
  end
end
