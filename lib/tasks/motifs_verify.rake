namespace :motifs do
  desc "Verify and fix broken image URLs in motifs database"
  task verify_images: :environment do
    puts "Checking all motif image URLs..."

    broken = []
    fixed = []

    Motif.find_each do |motif|
      if motif.image_1x1_url.present?
        # Check if URL looks broken or unreachable
        uri = URI.parse(motif.image_1x1_url) rescue nil

        # Flag suspicious URLs
        if uri.nil? || uri.scheme.nil? || !%w[http https].include?(uri.scheme)
          broken << {
            name: motif.name,
            slug: motif.slug,
            url: motif.image_1x1_url,
            kind: motif.kind
          }

          if ENV["FIX"] == "1"
            puts "  Clearing broken URL for #{motif.name}: #{motif.image_1x1_url}"
            motif.update_column(:image_1x1_url, nil)
            fixed << motif.name
          end
        else
          puts "✓ #{motif.name} (#{motif.kind}): #{motif.image_1x1_url[0..60]}..."
        end
      else
        # Check if asset file exists
        slug = motif.slug
        folder = (motif.kind == "spirit_animal") ? "spirit-animals" : "archetypes"
        asset_exists = false

        %w[png jpg jpeg webp].each do |ext|
          path = Rails.root.join("app", "assets", "images", folder, "#{slug}.#{ext}")
          if path.exist?
            asset_exists = true
            puts "✓ #{motif.name} (#{motif.kind}): Uses asset #{folder}/#{slug}.#{ext}"
            break
          end
        end

        unless asset_exists
          puts "⚠ #{motif.name} (#{motif.kind}): No DB URL or asset file (will use placeholder)"
        end
      end
    end

    if broken.any?
      puts "\n❌ Found #{broken.count} motif(s) with broken/invalid URLs:"
      broken.each do |m|
        puts "  - #{m[:name]} (#{m[:kind]}): #{m[:url]}"
      end

      unless ENV["FIX"] == "1"
        puts "\nRun with FIX=1 to clear these broken URLs:"
        puts "  bin/rails motifs:verify_images FIX=1"
      end
    end

    if fixed.any?
      puts "\n✅ Fixed #{fixed.count} motif(s): #{fixed.join(', ')}"
    end

    if broken.empty?
      puts "\n✅ All motif URLs are valid!"
    end
  end

  desc "List all motifs with their image sources"
  task list_images: :environment do
    puts "\nArchetypes:"
    puts "-" * 80

    Motif.where(kind: "archetype").order(:name).each do |m|
      source = if m.image_1x1_url.present?
        "DB: #{m.image_1x1_url[0..50]}..."
      else
        folder = "archetypes"
        found = nil
        %w[png jpg jpeg webp].each do |ext|
          path = Rails.root.join("app", "assets", "images", folder, "#{m.slug}.#{ext}")
          if path.exist?
            found = "Asset: #{folder}/#{m.slug}.#{ext}"
            break
          end
        end
        found || "Placeholder"
      end

      puts "#{m.name.ljust(20)} #{source}"
    end

    puts "\nSpirit Animals:"
    puts "-" * 80

    Motif.where(kind: "spirit_animal").order(:name).each do |m|
      source = if m.image_1x1_url.present?
        "DB: #{m.image_1x1_url[0..50]}..."
      else
        folder = "spirit-animals"
        found = nil
        %w[png jpg jpeg webp].each do |ext|
          path = Rails.root.join("app", "assets", "images", folder, "#{m.slug}.#{ext}")
          if path.exist?
            found = "Asset: #{folder}/#{m.slug}.#{ext}"
            break
          end
        end
        found || "Placeholder"
      end

      puts "#{m.name.ljust(25)} #{source}"
    end
  end
end
