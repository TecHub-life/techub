# frozen_string_literal: true

namespace :sbom do
  SBOM_PATH = "/home/loftwah/gits/techub/tmp/sbom-techub-image.cdx.json/sbom-techub-image.cdx.json"

  desc "Show top-level keys of the SBOM (safe overview)"
  task :keys do
    sh %(jq -C 'keys' "#{SBOM_PATH}" | less -R)
  end

  desc "Count components in the SBOM"
  task :count_components do
    sh %(jq '.components | length' "#{SBOM_PATH}")
  end

  desc "List the first N components (default 100)"
  task :list, [ :limit ] do |_t, args|
    limit = (args[:limit] || 100).to_i
    sh %(jq -r '.components[] | "\\(.name)\t\\(.version)\t\\(.purl // \"\")"' "#{SBOM_PATH}" | head -n #{limit})
  end

  desc "Find components by name using case-insensitive regex (usage: rake sbom:find['rails',10])"
  task :find, [ :regex, :limit ] do |_t, args|
    regex = args[:regex]
    limit = (args[:limit] || 0).to_i
    if regex.nil? || regex.strip.empty?
      abort "Usage: rake sbom:find['<regex>'[,<limit>]]"
    end

    if limit > 0
      # Use jq's limit() to avoid SIGPIPE and noisy errors
      sh %(jq -r --arg re '#{regex}' 'limit(#{limit}; .components[] | select(.name|test($re;"i")) | "\\(.name)\t\\(.version)\t\\(.purl // \"\")")' "#{SBOM_PATH}")
    else
      sh %(jq -r --arg re '#{regex}' '.components[] | select(.name|test($re;"i")) | "\\(.name)\t\\(.version)\t\\(.purl // \"\")"' "#{SBOM_PATH}")
    end
  end

  desc "Compress SBOM to sbom-techub-image.cdx.json.gz (keeps original)"
  task :compress do
    sh %(gzip -9kf "#{SBOM_PATH}")
  end

  desc "Print component count from gzipped SBOM (no temp files)"
  task :count_gz do
    sh %(zcat "#{SBOM_PATH}.gz" | jq '.components | length')
  end

  desc "Export components as NDJSON to tmp/components.ndjson"
  task :ndjson do
    out = "/home/loftwah/gits/techub/tmp/components.ndjson"
    sh %(jq -c '.components[]' "#{SBOM_PATH}" > "#{out}")
    puts "Wrote #{out}"
  end

  desc "Split NDJSON into chunks of N lines (default 5000). Requires sbom:ndjson first."
  task :split, [ :lines ] do |_t, args|
    lines = (args[:lines] || 5000).to_i
    ndjson = "/home/loftwah/gits/techub/tmp/components.ndjson"
    unless File.exist?(ndjson)
      abort "#{ndjson} not found. Run: rake sbom:ndjson"
    end
    sh %(split -l #{lines} "#{ndjson}" "/home/loftwah/gits/techub/tmp/components_part_")
  end
end
