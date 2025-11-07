module AppearanceLibrary
  module_function

  AVATAR_DIRS = {
    "avatars-1x1" => "TecHub Avatars",
    "spirit-animals" => "Spirit Animals",
    "archetypes" => "Archetypes"
  }.freeze

  SUPPORTING_ART_DIRS = {
    "supporting-art-1x1" => "Supporting Art 1x1",
    "3x1-banners" => "3x1 Banners"
  }.freeze

  BANNER_DIRS = {
    "3x1-banners" => "TecHub Banners"
  }.freeze

  def avatar_options
    gather_options(AVATAR_DIRS)
  end

  def supporting_art_options
    gather_options(SUPPORTING_ART_DIRS)
  end

  def banner_options
    gather_options(BANNER_DIRS)
  end

  def gather_options(mapping)
    base = Rails.root.join("app", "assets", "images")
    mapping.flat_map do |dir, group_label|
      pattern = base.join(dir, "*.{jpg,jpeg,png,webp}")
      Dir[pattern.to_s].sort.map do |path|
        rel = Pathname.new(path).relative_path_from(base).to_s
        {
          id: "#{dir}:#{File.basename(path)}",
          label: "#{group_label} – #{humanize(path)}",
          path: rel
        }
      end
    end
  end

  def humanize(path)
    basename = File.basename(path, File.extname(path))
    basename.tr("_-", " ").split.map(&:capitalize).join(" ")
  end
end
