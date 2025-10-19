class ApiDocsController < ApplicationController
  def show
    @spec_path = openapi_spec_path
  end

  def spec
    path = Rails.root.join("docs", "api", "openapi.yaml")
    return head :not_found unless File.exist?(path)
    send_file path, type: "application/yaml", disposition: "inline"
  end
end
