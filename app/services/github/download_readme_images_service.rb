require "open-uri"
require "digest"

module Github
  class DownloadReadmeImagesService < ApplicationService
    def initialize(readme_content:, login:)
      @readme_content = readme_content
      @login = login
    end

    def call
      return success(readme_content) if readme_content.blank?

      # Create profile-specific directory
      profile_dir = Rails.root.join("public", "profile_images", login)
      FileUtils.mkdir_p(profile_dir)

      updated_content = readme_content.dup
      downloaded_images = []

      # Find all images in markdown format: ![alt](url)
      markdown_images = readme_content.scan(/!\[([^\]]*)\]\(([^\)]+)\)/)
      markdown_images.each do |alt_text, url|
        next unless url.match?(/^https?:\/\//)

        local_path = download_image(url, profile_dir)
        if local_path
          # Replace the URL with the local path
          updated_content.gsub!("](#{url})", "](#{local_path})")
          downloaded_images << { original: url, local: local_path }
        end
      end

      # Find all images in HTML format: <img src="url" ... >
      html_images = readme_content.scan(/<img[^>]+src=["']([^"']+)["'][^>]*>/i)
      html_images.flatten.each do |url|
        next unless url.match?(/^https?:\/\//)

        local_path = download_image(url, profile_dir)
        if local_path
          updated_content.gsub!(url, local_path)
          downloaded_images << { original: url, local: local_path }
        end
      end

      Rails.logger.info("Downloaded #{downloaded_images.length} images for #{login}'s profile README")

      success(
        {
          content: updated_content,
          images_downloaded: downloaded_images.length,
          images: downloaded_images
        }
      )
    rescue StandardError => e
      Rails.logger.error("Failed to download README images for #{login}: #{e.message}")
      # Return original content if download fails
      success(
        {
          content: readme_content,
          images_downloaded: 0,
          images: []
        }
      )
    end

    private

    attr_reader :readme_content, :login

    def download_image(url, profile_dir)
      # Generate a filename based on the URL
      uri = URI.parse(url)
      extension = File.extname(uri.path).presence || ".png"

      # Use hash of URL to create unique but consistent filename
      filename = "#{Digest::MD5.hexdigest(url)}#{extension}"
      local_file_path = profile_dir.join(filename)

      # Skip if already downloaded
      return "/profile_images/#{login}/#{filename}" if File.exist?(local_file_path)

      # Download the image
      URI.open(url, "rb", read_timeout: 10) do |image|
        File.binwrite(local_file_path, image.read)
      end

      "/profile_images/#{login}/#{filename}"
    rescue OpenURI::HTTPError, SocketError, Timeout::Error => e
      Rails.logger.warn("Failed to download image #{url}: #{e.message}")
      nil
    end
  end
end
