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
      filename_suffix: nil
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
    end

    def call
      description_path = source_avatar_path
      return failure(StandardError.new("Avatar image not found for #{login}"), metadata: { expected_path: description_path.to_s }) unless File.exist?(description_path)

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

    attr_reader :login, :avatar_path, :output_dir, :prompt_theme, :style_profile, :prompt_service, :image_service, :provider_override, :filename_suffix

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
