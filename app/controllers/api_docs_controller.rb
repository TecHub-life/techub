class ApiDocsController < ApplicationController
  def show
    # Path used by the HTML page to fetch the spec YAML
    @spec_path = api_docs_spec_path
  end

  def spec
    path = Rails.root.join("docs", "api", "openapi.yaml")
    return head :not_found unless File.exist?(path)
    send_file path, type: "application/yaml", disposition: "inline"
  end
end
