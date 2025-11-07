module MyProfilesHelper
  def avatar_mode_for(profile, variant)
    normalized = variant.to_s
    id = avatar_source_id(profile, normalized)
    return "inherit" if id.nil? && normalized != "default"

    provider, = AvatarSources.parse(id || "github")
    case provider
    when :library then "library"
    when :upload then "upload"
    else "github"
    end
  end

  def avatar_library_path_for(profile, variant)
    id = avatar_source_id(profile, variant)
    return nil unless id.to_s.start_with?("library:")
    id.split(":", 2).last
  end

  def avatar_source_label(profile, variant = :default)
    normalized = variant.to_s
    id = avatar_source_id(profile, normalized)
    return "Inherits default avatar" if id.nil? && normalized != "default"
    id ||= "github"

    provider, payload = AvatarSources.parse(id)
    case provider
    when :github
      "GitHub avatar"
    when :upload
      "Custom upload"
    when :library
      "Library · #{appearance_library_label_for(payload)}"
    else
      provider.to_s.titleize
    end
  end

  def banner_source_label(profile)
    case profile.banner_choice.to_s
    when "library"
      "TecHub library · #{appearance_library_label_for(profile.banner_library_path)}"
    when "upload"
      "Custom upload"
    else
      "Hidden / none"
    end
  end

  def supporting_art_source_label(profile, variant)
    card = profile.profile_card
    choice_attr = :"bg_choice_#{variant}"
    color_attr = :"bg_color_#{variant}"
    choice = card&.public_send(choice_attr).presence || "library"

    case choice
    when "upload"
      "Custom upload · shared across cards"
    when "color"
      color = card&.public_send(color_attr).presence || "#0f172a"
      "Solid colour · #{color.upcase}"
    else
      path = bg_library_path_for(profile, variant)
      "TecHub library · #{appearance_library_label_for(path)}"
    end
  rescue StandardError
    "TecHub library"
  end

  def appearance_library_label_for(path)
    return "TecHub rotation" if path.to_s.blank?
    folder = path.to_s.split("/").first.to_s.titleize
    name = File.basename(path, File.extname(path)).tr("_-", " ").titleize
    "#{folder} / #{name}"
  rescue StandardError
    "TecHub rotation"
  end

  def bg_library_path_for(profile, variant)
    card = profile.profile_card
    sources = card&.bg_sources_hash || {}
    entry = sources[variant.to_s]
    entry ||= sources["simple"] if variant.to_s == "square"
    entry&.dig("path")
  end

  def banner_library_path_for(profile)
    profile.banner_library_path
  end

  def profile_uploaded_asset_url(profile, kind)
    asset = profile.profile_assets.find_by(kind: kind)
    return asset.public_url if asset&.public_url.present?
    generated_asset_url(profile, kind)
  end

  def saved_avatar_preview_url(profile)
    mode = avatar_mode_for(profile, :default)
    case mode
    when "library"
      library = avatar_library_path_for(profile, :default)
      library.present? ? asset_path(library) : asset_path("android-chrome-512x512.jpg")
    when "upload"
      profile_uploaded_asset_url(profile, "avatar_1x1") || asset_path("android-chrome-512x512.jpg")
    else
      profile.avatar_url.presence || asset_path("android-chrome-512x512.jpg")
    end
  rescue StandardError
    asset_path("android-chrome-512x512.jpg")
  end

  def library_picker(options:, name:, selected:, image_ratio: "aspect-square", columns: "grid-cols-2 sm:grid-cols-4 lg:grid-cols-5")
    content_tag(:div, class: "max-h-64 overflow-y-auto #{columns} grid gap-3 pr-1") do
      options.map do |opt|
        label = truncate(opt[:label], length: 42)
        content_tag(:label, class: "cursor-pointer block") do
          tag.input(type: "radio", name: name, value: opt[:path], class: "peer sr-only", checked: selected.present? && selected == opt[:path]) +
          content_tag(:div, class: "rounded-lg border border-slate-200 bg-white p-1 shadow-sm transition peer-checked:border-indigo-500 peer-checked:ring-2 peer-checked:ring-indigo-200 dark:border-slate-600 dark:bg-slate-900/80 dark:peer-checked:ring-indigo-900") do
            content_tag(:div, class: "#{image_ratio} w-full overflow-hidden rounded-md bg-slate-100 dark:bg-slate-800") do
              image_tag(opt[:path], class: "h-full w-full object-cover")
            end +
            content_tag(:p, label, class: "mt-1 text-[11px] font-medium text-slate-700 dark:text-slate-200")
          end
        end
      end.join.html_safe
    end
  end

  private

  def avatar_source_id(profile, variant)
    card = profile.profile_card
    return nil unless card
    card.avatar_source_id_for(variant.to_s, fallback: false)
  end

  def generated_asset_url(profile, kind)
    safe_login = profile.login.to_s.downcase.gsub(/[^a-z0-9\-]/, "")
    return if safe_login.blank?
    dir = Rails.root.join("public", "generated", safe_login)
    pattern = dir.join("#{kind}-custom*")
    file = Dir[pattern.to_s].sort.last
    return unless file
    "/generated/#{safe_login}/#{File.basename(file)}"
  rescue StandardError
    nil
  end
end
