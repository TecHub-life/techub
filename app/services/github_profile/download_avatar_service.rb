require "open-uri"

module GithubProfileProfile
  class DownloadAvatarService < ApplicationService
    def initialize(avatar_url:, login:)
      @avatar_url = avatar_url
      @login = login
    end

    def call
      return failure(StandardError.new("Avatar URL is blank")) if avatar_url.blank?
      return failure(StandardError.new("Login is blank")) if login.blank?

      # Validate URL before processing
      uri = URI.parse(avatar_url)

      # Only allow HTTP and HTTPS protocols
      unless %w[http https].include?(uri.scheme)
        return failure(StandardError.new("Invalid URL scheme"))
      end

      # Validate hostname to prevent SSRF attacks
      unless uri.host && !uri.host.empty?
        return failure(StandardError.new("Invalid hostname"))
      end

      # Block private/internal IP addresses
      if private_ip?(uri.host)
        return failure(StandardError.new("Private IP addresses not allowed"))
      end

      # Create filename based on login and timestamp
      extension = File.extname(uri.path).presence || ".png"
      filename = "#{login}#{extension}"
      local_path = Rails.root.join("public", "avatars", filename)

      # Download the avatar with additional security measures
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 3) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "TechHub/1.0"

        response = http.request(request)

        # Validate response
        unless response.is_a?(Net::HTTPSuccess)
          return failure(StandardError.new("HTTP #{response.code}"))
        end

        # Validate content type
        content_type = response["content-type"]
        unless content_type&.start_with?("image/")
          return failure(StandardError.new("Invalid content type: #{content_type}"))
        end

        # Limit file size (2MB max for avatars)
        if response["content-length"] && response["content-length"].to_i > 2.megabytes
          return failure(StandardError.new("Avatar too large"))
        end

        File.binwrite(local_path, response.body)
      end

      # Return the public URL path
      public_path = "/avatars/#{filename}"
      success(public_path)
    rescue Net::HTTPError, SocketError, URI::InvalidURIError => e
      failure(e)
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

    private

    attr_reader :avatar_url, :login
  end
end
