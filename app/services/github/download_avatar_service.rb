require "open-uri"

module Github
  class DownloadAvatarService < ApplicationService
    def initialize(avatar_url:, login:)
      @avatar_url = avatar_url
      @login = login
    end

    def call
      return failure(StandardError.new("Avatar URL is blank")) if avatar_url.blank?
      return failure(StandardError.new("Login is blank")) if login.blank?

      # Create filename based on login and timestamp
      extension = File.extname(URI.parse(avatar_url).path).presence || ".png"
      filename = "#{login}#{extension}"
      local_path = Rails.root.join("public", "avatars", filename)

      # Download the avatar
      URI.open(avatar_url) do |image|
        File.binwrite(local_path, image.read)
      end

      # Return the public URL path
      public_path = "/avatars/#{filename}"
      success(public_path)
    rescue OpenURI::HTTPError, SocketError => e
      failure(e)
    end

    private

    attr_reader :avatar_url, :login
  end
end
