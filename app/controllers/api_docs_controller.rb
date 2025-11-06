class ApiDocsController < ApplicationController
  def show
    path = Rails.root.join("docs", "api", "openapi.yaml")
    @spec = File.exist?(path) ? YAML.safe_load(File.read(path)) : {}
  end

  def spec
    path = Rails.root.join("docs", "api", "openapi.yaml")
    return head :not_found unless File.exist?(path)
    send_file path, type: "application/yaml", disposition: "inline"
  end
end
