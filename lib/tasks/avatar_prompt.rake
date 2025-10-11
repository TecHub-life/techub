namespace :gemini do
  PROVIDER_ORDER = %w[ai_studio vertex].freeze

  def self.each_provider
    PROVIDER_ORDER.each do |provider|
      yield provider
    end
  end

  desc "Describe a GitHub avatar and build prompts. Usage: rake gemini:avatar_prompt[login] or LOGIN=loftwah STYLE='Neon-lit anime portrait' rake gemini:avatar_prompt"
  task :avatar_prompt, [ :login, :avatar_path, :style, :provider ] => :environment do |_, args|
    login = args[:login] || ENV["LOGIN"] || "loftwah"
    avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
    style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE
    provider = args[:provider] || ENV["PROVIDER"]

    if login.blank? && avatar_path.blank?
      puts "Provide a GitHub login or an explicit avatar path. Example: rake gemini:avatar_prompt[loftwah]"
      exit 1
    end

    avatar_path ||= Rails.root.join("public", "avatars", "#{login}.png")

    result = Gemini::AvatarPromptService.call(
      avatar_path: avatar_path,
      style_profile: style_profile,
      provider: provider
    )

    if result.failure?
      warn "Avatar prompt generation failed: #{result.error.message}"
      if login.present?
        warn "Expected avatar at #{avatar_path}. Run Profiles::SyncFromGithub or download the avatar first."
      end
      if result.metadata.present?
        warn "Metadata: #{result.metadata}"
      end
      exit 1
    end

    structured = result.value[:structured_description]
    if structured.present?
      puts "Avatar description:\n#{structured['description']}"
      detail_pairs = structured.except("description")
      unless detail_pairs.empty?
        puts "\nKey details:"
        detail_pairs.each do |key, value|
          puts "- #{key.tr('_', ' ')}: #{value}"
        end
      end
    else
      puts "Avatar description:\n#{result.value[:avatar_description]}"
    end

    puts "\nTecHub image prompts:"
    result.value[:image_prompts].each do |variant, prompt|
      puts "\n[#{variant}]"
      puts prompt
    end

    unless result.metadata.blank?
      puts "\nMetadata: #{result.metadata}"
    end
  end

  desc "Describe an avatar and generate TecHub image variants (1x1, 16x9, 3x1, 9x16). Usage: rake gemini:avatar_generate[login]"
  task :avatar_generate, [ :login, :style, :avatar_path, :output_dir, :provider ] => :environment do |_, args|
    login = args[:login] || ENV["LOGIN"] || "loftwah"

    style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE
    avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
    output_dir = args[:output_dir] || ENV["OUTPUT_DIR"] || Rails.root.join("public", "generated").to_s
    provider = args[:provider] || ENV["PROVIDER"]

    require_eligibility = [ "1", "true", "yes" ].include?(ENV["REQUIRE_ELIGIBILITY"].to_s.downcase)
    eligibility_threshold = (ENV["ELIGIBILITY_THRESHOLD"] || Eligibility::GithubProfileScoreService::DEFAULT_THRESHOLD).to_i

    result = Gemini::AvatarImageSuiteService.call(
      login: login,
      avatar_path: avatar_path,
      output_dir: output_dir,
      style_profile: style_profile,
      provider: provider,
      require_profile_eligibility: require_eligibility,
      eligibility_threshold: eligibility_threshold
    )

    if result.failure?
      warn "Avatar image generation failed: #{result.error.message}"
      warn "Metadata: #{result.metadata}" if result.metadata.present?
      exit 1
    end

    puts "Avatar description:\n#{result.value[:avatar_description]}"
    puts "\nSaved image variants to #{result.value[:output_dir]}:"
    result.value[:images].each do |variant, payload|
      line = "- #{variant} (#{payload[:mime_type]}) -> #{payload[:output_path]}"
      line += " [url: #{payload[:public_url]}]" if payload[:public_url].present?
      puts line
    end
    unless result.metadata.blank?
      puts "\nMetadata: #{result.metadata}"
    end
  end

  desc "Generate a short narrative using a stored profile: rake gemini:profile_story[login]"
  task :profile_story, [ :login, :provider ] => :environment do |_, args|
    login = args[:login] || ENV["LOGIN"] || "loftwah"
    provider = args[:provider] || ENV["PROVIDER"]

    result = Profiles::StoryFromProfile.call(login: login, provider: provider)

    if result.failure?
      warn "Story generation failed: #{result.error.message}"
      warn "Metadata: #{result.metadata}" if result.metadata.present?
      exit 1
    end

    puts "Micro-story for #{login}:\n\n#{result.value}"
    puts "\nMetadata: #{result.metadata}" unless result.metadata.blank?
  end

  namespace :avatar_prompt do
    desc "Run avatar prompt against both providers for quick verification"
    task :verify, [ :login, :avatar_path, :style ] => :environment do |_, args|
      verbose = [ "1", "true", "yes" ].include?(ENV["VERBOSE"].to_s.downcase)
      login = args[:login] || ENV["LOGIN"]
      avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
      style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE

      if login.blank? && avatar_path.blank?
        warn "Usage: rake gemini:avatar_prompt:verify[github_login]"
        exit 1
      end

      avatar_path ||= Rails.root.join("public", "avatars", "#{login}.png")

      PROVIDER_ORDER.each do |provider|
        puts "\n=== Avatar prompt via #{provider} ==="
        result = Gemini::AvatarPromptService.call(
          avatar_path: avatar_path,
          style_profile: style_profile,
          provider: provider
        )

        if result.success?
          puts "Provider #{provider} OK."
          if verbose
            puts "- Provider: #{provider}"
            puts "- Theme: #{result.metadata[:theme]}"
            puts "- Style profile: #{result.metadata[:style_profile]}"
          end
          puts "- Description: #{result.value[:avatar_description]}"
          puts "\nTecHub image prompts:"
          result.value[:image_prompts].each do |variant, prompt|
            puts "\n[#{variant}]"
            puts prompt
          end
          if verbose && result.value[:structured_description].present?
            puts "\nStructured details:"
            result.value[:structured_description].except("description").each do |k, v|
              puts "- #{k.tr('_', ' ')}: #{v}"
            end
          end
        else
          warn "Provider #{provider} FAILED: #{result.error.message}"
          warn "Metadata: #{result.metadata.inspect}"
        end
      end
    end
  end

  namespace :avatar_generate do
    desc "Generate avatar variants via both providers (writes files)"
    task :verify, [ :login, :style, :avatar_path, :output_dir ] => :environment do |_, args|
      verbose = [ "1", "true", "yes" ].include?(ENV["VERBOSE"].to_s.downcase)
      login = args[:login] || ENV["LOGIN"] || "loftwah"

      style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE
      avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
      output_dir = args[:output_dir] || ENV["OUTPUT_DIR"] || Rails.root.join("public", "generated").to_s

      require_eligibility = [ "1", "true", "yes" ].include?(ENV["REQUIRE_ELIGIBILITY"].to_s.downcase)
      eligibility_threshold = (ENV["ELIGIBILITY_THRESHOLD"] || Eligibility::GithubProfileScoreService::DEFAULT_THRESHOLD).to_i

      PROVIDER_ORDER.each do |provider|
        puts "\n=== Avatar generate via #{provider} ==="
        result = Gemini::AvatarImageSuiteService.call(
          login: login,
          avatar_path: avatar_path,
          output_dir: output_dir,
          style_profile: style_profile,
          provider: provider,
          filename_suffix: provider,
          require_profile_eligibility: require_eligibility,
          eligibility_threshold: eligibility_threshold
        )

        if result.success?
          puts "Provider #{provider} OK. Images in #{result.value[:output_dir]}"
          if verbose
            puts "- Provider: #{(result.metadata || {})[:provider] || provider}"
            puts "- Theme: #{(result.metadata || {})[:theme]}"
            puts "- Style profile: #{(result.metadata || {})[:style_profile]}"
            puts "\nExact prompts used:"
            (result.value[:prompts] || {}).each do |variant, prompt|
              puts "\n[#{variant}]"
              puts prompt
            end
          end
          images = result.value[:images] || {}
          images.each do |variant, payload|
            line = "- #{variant} (#{payload[:mime_type]}) -> #{payload[:output_path]}"
            line += " [url: #{payload[:public_url]}]" if payload[:public_url].present?
            puts line
          end
        else
          warn "Provider #{provider} FAILED: #{result.error.message}"
          warn "Metadata: #{result.metadata.inspect}"
        end
      end
    end
  end

  namespace :profile_story do
    desc "Generate profile story via both providers"
    task :verify, [ :login ] => :environment do |_, args|
      verbose = [ "1", "true", "yes" ].include?(ENV["VERBOSE"].to_s.downcase)
      login = args[:login] || ENV["LOGIN"] || "loftwah"

      PROVIDER_ORDER.each do |provider|
        puts "\n=== Profile story via #{provider} ==="
        result = Profiles::StoryFromProfile.call(login: login, provider: provider)

        if result.success?
          puts "Provider #{provider} OK. Finish reason: #{result.metadata[:finish_reason]}"
          if verbose
            puts "- Provider: #{result.metadata[:provider] || provider}"
            puts "- Attempts: #{Array(result.metadata[:attempts]).size}"
            puts "- Metadata: #{result.metadata.inspect}"
          end
          puts result.value
        else
          warn "Provider #{provider} FAILED: #{result.error.message}"
          warn "Metadata: #{result.metadata.inspect}"
        end
      end
    end
  end

  desc "Run all Gemini verification tasks for a given login"
  task :verify_all, [ :login, :avatar_path, :style, :output_dir ] => :environment do |_, args|
    login = args[:login] || ENV["LOGIN"] || "loftwah"

    avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
    style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE
    output_dir = args[:output_dir] || ENV["OUTPUT_DIR"] || Rails.root.join("tmp", "generated_verify").to_s

    Rake::Task["gemini:avatar_prompt:verify"].invoke(login, avatar_path, style_profile)
    # Reenable so it can run again in the same rake process if needed
    Rake::Task["gemini:avatar_prompt:verify"].reenable

    Rake::Task["gemini:avatar_generate:verify"].invoke(login, style_profile, avatar_path, output_dir)
    Rake::Task["gemini:avatar_generate:verify"].reenable

    Rake::Task["gemini:profile_story:verify"].invoke(login)
    Rake::Task["gemini:profile_story:verify"].reenable
  end
end
