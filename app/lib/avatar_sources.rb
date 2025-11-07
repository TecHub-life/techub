module AvatarSources
  module_function

  def normalize_id(mode:, path: nil)
    case mode.to_s
    when "library"
      return nil if path.to_s.blank?
      "library:#{path}"
    when "upload"
      "upload:avatar_1x1"
    when "github", ""
      "github"
    else
      mode.to_s
    end
  end

  def parse(id)
    token = id.to_s
    return [ :github, nil ] if token.blank? || token == "github"

    if token.start_with?("library:")
      [ :library, token.sub(/\Alibrary:/, "") ]
    elsif token.start_with?("upload:")
      [ :upload, token.split(":", 2).last.presence || "avatar_1x1" ]
    else
      [ token.to_sym, nil ]
    end
  end
end
