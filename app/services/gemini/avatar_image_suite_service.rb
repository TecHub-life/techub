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
      prompts = prompts_result.value[:image_prompts]

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

        generated[key] = result.value.merge(aspect_ratio: variant[:aspect_ratio])
      end

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
      record = Profile.includes(:profile_repositories, :profile_organizations, :profile_social_accounts, :profile_languages).find_by(login: login.downcase) rescue nil
      return {} unless record

      {
        name: record.respond_to?(:name) ? (record.name.presence || record.login) : record.login,
        summary: record.respond_to?(:summary) ? record.summary.to_s.strip : "",
        languages: fetch_names(record, :profile_languages, :name, limit: 5),
        top_repositories: fetch_repo_names(record),
        organizations: fetch_org_names(record)
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

    def filename_with_suffix(filename)
      return filename unless filename_suffix.to_s.strip.present?

      base = File.basename(filename, File.extname(filename))
      ext = File.extname(filename)
      "#{base}-#{filename_suffix}#{ext}"
    end
  end
end
