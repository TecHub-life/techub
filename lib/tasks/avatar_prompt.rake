namespace :gemini do
  desc "Describe a GitHub avatar and build TecHub-styled prompts. Usage: rake gemini:avatar_prompt[login] or LOGIN=loftwah STYLE='Neon anime hero energy' rake gemini:avatar_prompt"
  task :avatar_prompt, [ :login, :avatar_path, :style ] => :environment do |_, args|
    login = args[:login] || ENV["LOGIN"]
    avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
    style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE

    if login.blank? && avatar_path.blank?
      puts "Provide a GitHub login or an explicit avatar path. Example: rake gemini:avatar_prompt[loftwah]"
      exit 1
    end

    avatar_path ||= Rails.root.join("public", "avatars", "#{login}.png")

    result = Gemini::AvatarPromptService.call(
      avatar_path: avatar_path,
      style_profile: style_profile
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
  task :avatar_generate, [ :login, :style, :avatar_path, :output_dir ] => :environment do |_, args|
    login = args[:login] || ENV["LOGIN"]
    unless login.present?
      warn "Usage: rake gemini:avatar_generate[github_login]"
      exit 1
    end

    style_profile = args[:style] || ENV["STYLE"] || Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE
    avatar_path = args[:avatar_path] || ENV["AVATAR_PATH"]
    output_dir = args[:output_dir] || ENV["OUTPUT_DIR"] || Rails.root.join("public", "generated").to_s

    result = Gemini::AvatarImageSuiteService.call(
      login: login,
      avatar_path: avatar_path,
      output_dir: output_dir,
      style_profile: style_profile
    )

    if result.failure?
      warn "Avatar image generation failed: #{result.error.message}"
      warn "Metadata: #{result.metadata}" if result.metadata.present?
      exit 1
    end

    puts "Avatar description:\n#{result.value[:avatar_description]}"
    puts "\nSaved image variants to #{result.value[:output_dir]}:"
    result.value[:images].each do |variant, payload|
      puts "- #{variant} (#{payload[:mime_type]}) -> #{payload[:output_path]}"
    end
    unless result.metadata.blank?
      puts "\nMetadata: #{result.metadata}"
    end
  end
end
