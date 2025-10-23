module ApplicationHelper
  # Convert a relative path (or already absolute URL) into a full absolute URL.
  def absolute_url_for(path)
    return if path.blank?

    str = path.to_s
    return str if str.start_with?("http://", "https://")

    root = request.base_url
    normalized = str.start_with?("/") ? str : "/#{str}"
    "#{root}#{normalized}"
  end

  # Compute an absolute URL for an asset managed by the pipeline or served from /public.
  def full_asset_url(logical_path)
    relative = asset_path(logical_path)
    absolute_url_for(relative)
  rescue Sprockets::Rails::Helper::AssetNotFound
    absolute_url_for("/#{logical_path}".squeeze("/"))
  end
end
