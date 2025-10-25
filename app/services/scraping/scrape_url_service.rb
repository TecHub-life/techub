require "net/http"
require "uri"

module Scraping
  class ScrapeUrlService < ApplicationService
    DEFAULT_MAX_BYTES = 2 * 1024 * 1024 # 2MB
    DEFAULT_TIMEOUT = 10 # seconds
    DEFAULT_MAX_TEXT_CHARS = 20_000
    DEFAULT_MAX_LINKS = 50
    MAX_REDIRECTS = 3

    def initialize(url:, allowed_hosts: nil, max_bytes: DEFAULT_MAX_BYTES, timeout: DEFAULT_TIMEOUT, max_text_chars: DEFAULT_MAX_TEXT_CHARS, max_links: DEFAULT_MAX_LINKS)
      @url = url.to_s
      @allowed_hosts = Array(allowed_hosts).presence
      @max_bytes = max_bytes
      @timeout = timeout
      @max_text_chars = max_text_chars
      @max_links = max_links
    end

    def call
      uri = parse_and_validate_url(url)
      return failure(StandardError.new("invalid_url")) unless uri

      return failure(StandardError.new("host_not_allowed")) unless host_allowed?(uri)
      return failure(StandardError.new("private_address_blocked")) if private_address?(uri)

      response = fetch_with_redirects(uri, MAX_REDIRECTS)
      return failure(StandardError.new("http_error")) unless response.is_a?(Net::HTTPSuccess)

      content_type = response["content-type"] || ""
      return failure(StandardError.new("unsupported_content_type")) unless content_type.include?("text/html") || content_type.include?("application/xhtml")

      html = response.body.to_s
      return failure(StandardError.new("empty_body")) if html.strip.empty?

      parsed = parse_html(html, uri)
      success(parsed, metadata: { url: uri.to_s, content_type: content_type, http_status: response.code.to_i, bytes: html.bytesize })
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :url, :allowed_hosts, :max_bytes, :timeout, :max_text_chars, :max_links

    def parse_and_validate_url(raw)
      candidate = normalize_url(raw)
      uri = URI.parse(candidate)
      # Ensure a trailing slash for bare host URLs to produce stable keys
      if (uri.path.nil? || uri.path.empty?) && uri.query.nil? && uri.fragment.nil?
        uri.path = "/"
      end
      return nil unless uri.is_a?(URI::HTTP)
      return nil if uri.host.blank?
      uri
    rescue URI::InvalidURIError
      nil
    end

    def normalize_url(raw)
      s = raw.to_s.strip
      return s if s =~ /\A[a-z][a-z0-9+\-.]*:\/\//i
      return "" if s.empty?
      "https://#{s}"
    end

    def host_allowed?(uri)
      return true if allowed_hosts.blank?
      allowed_hosts.include?(uri.host)
    end

    def private_address?(uri)
      # Block localhost and private ranges
      host = uri.host
      return true if host == "localhost" || host.end_with?(".localhost")
      return true if host =~ /^(127\.0\.0\.1|::1)$/

      # If host is an IP, check private ranges
      if host =~ /^(\d{1,3}\.){3}\d{1,3}$/
        octets = host.split(".").map(&:to_i)
        return true if octets[0] == 10
        return true if octets[0] == 172 && (16..31).include?(octets[1])
        return true if octets[0] == 192 && octets[1] == 168
      end
      false
    end

    def fetch_with_redirects(uri, remaining)
      raise StandardError, "too_many_redirects" if remaining < 0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = timeout
      http.open_timeout = timeout

      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = "TecHubScraper/1.0 (+https://techub.life)"
      req["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

      bytes_read = 0
      body = +""
      response = nil

      http.request(req) do |res|
        response = res
        if res.is_a?(Net::HTTPRedirection)
          location = res["location"]
          raise StandardError, "redirect_without_location" if location.blank?
          next_uri = URI.join(uri, location)
          return fetch_with_redirects(next_uri, remaining - 1)
        end

        res.read_body do |chunk|
          bytes_read += chunk.bytesize
          break if bytes_read > max_bytes
          body << chunk
        end
      end

      # Build a success-like response with truncated body if needed
      if response.is_a?(Net::HTTPSuccess)
        # emulate Net::HTTPResponse with body replaced
        response.instance_variable_set(:@read, true)
        response.instance_variable_set(:@body, body)
      end
      response
    end

    def parse_html(html, base_uri)
      require "nokogiri"

      doc = Nokogiri::HTML(html)
      title = doc.at("title")&.text&.strip
      meta_desc = doc.at('meta[name="description"]')&.[]("content")&.strip
      og_desc = doc.at('meta[property="og:description"]')&.[]("content")&.strip
      canonical_href = doc.at('link[rel="canonical"]')&.[]("href")
      canonical = if canonical_href
        begin
          URI.join(base_uri, canonical_href).to_s
        rescue StandardError
          canonical_href
        end
      else
        nil
      end

      # Extract visible text (basic heuristic; avoids script/style/nav)
      doc.search("script,style,noscript,header,footer,nav").remove
      main = doc.at("main") || doc.at("article") || doc.at("body")
      text = main ? main.text : doc.text
      text = text.gsub(/\s+/, " ").strip
      text = text[0, max_text_chars]

      # Extract absolute links up to cap
      links = doc.css("a[href]").map { |a| a["href"] }.compact
      links = links.map { |href| URI.join(base_uri, href).to_s rescue nil }.compact.uniq.first(max_links)

      {
        title: title,
        description: meta_desc || og_desc,
        canonical_url: canonical,
        text: text,
        links: links
      }
    end
  end
end
