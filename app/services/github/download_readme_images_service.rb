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
      # Validate URL before processing
      uri = URI.parse(url)

      # Only allow HTTP and HTTPS protocols
      unless %w[http https].include?(uri.scheme)
        Rails.logger.warn("Invalid URL scheme for image download: #{url}")
        return nil
      end

      # Validate hostname to prevent SSRF attacks
      unless uri.host && !uri.host.empty?
        Rails.logger.warn("Invalid hostname for image download: #{url}")
        return nil
      end

      # Block private/internal IP addresses
      if private_ip?(uri.host)
        Rails.logger.warn("Blocked private IP address for image download: #{url}")
        return nil
      end

      extension = File.extname(uri.path).presence || ".png"

      # Use hash of URL to create unique but consistent filename
      filename = "#{Digest::MD5.hexdigest(url)}#{extension}"
      local_file_path = profile_dir.join(filename)

      # Skip if already downloaded
      return "/profile_images/#{login}/#{filename}" if File.exist?(local_file_path)

      # Download the image with additional security measures
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 3) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "TechHub/1.0"

        response = http.request(request)

        # Validate response
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("Failed to download image #{url}: HTTP #{response.code}")
          return nil
        end

        # Validate content type
        content_type = response["content-type"]
        unless content_type&.start_with?("image/")
          Rails.logger.warn("Invalid content type for image download: #{url} (#{content_type})")
          return nil
        end

        # Limit file size (5MB max)
        if response["content-length"] && response["content-length"].to_i > 5.megabytes
          Rails.logger.warn("Image too large for download: #{url}")
          return nil
        end

        File.binwrite(local_file_path, response.body)
      end

      "/profile_images/#{login}/#{filename}"
    rescue Net::HTTPError, SocketError, Timeout::Error, URI::InvalidURIError => e
      Rails.logger.warn("Failed to download image #{url}: #{e.message}")
      nil
    end

    def private_ip?(hostname)
      # Resolve hostname to IP address
      ip = Resolv.getaddress(hostname)

      # Check for private IP ranges
      private_ranges = [
        IPAddr.new("10.0.0.0/8"),
        IPAddr.new("172.16.0.0/12"),
        IPAddr.new("192.168.0.0/16"),
        IPAddr.new("127.0.0.0/8"),
        IPAddr.new("169.254.0.0/16"),
        IPAddr.new("::1/128"),
        IPAddr.new("fc00::/7"),
        IPAddr.new("fe80::/10")
      ]

      private_ranges.any? { |range| range.include?(ip) }
    rescue Resolv::ResolvError
      # If we can't resolve the hostname, err on the side of caution
      true
    end
  end
end
