require "set"
module Motifs
  class GenerateLibraryService < ApplicationService
    DEFAULT_THEME = "core".freeze
    DEFAULT_VARIANTS = [ "1:1", "16:9" ].freeze # 1x1 (universal), 16x9 (OG/banner base)

    def initialize(theme: DEFAULT_THEME, ensure_only: false, variants: DEFAULT_VARIANTS, lore_only: false, images_only: false, only: nil, limit: nil)
      @theme = sanitize_theme(theme)
      @ensure_only = !!ensure_only
      @variants = Array(variants).presence || DEFAULT_VARIANTS
      @lore_only = !!lore_only
      @images_only = !!images_only
      @only_slugs = normalize_only(only)
      @limit = limit.to_i if limit
    end

    def call
      generated = { archetypes: [], spirit_animals: [] }

      generated[:archetypes] = generate_set(
        kind: :archetypes,
        entries: Motifs::Catalog.archetype_entries
      )

      generated[:spirit_animals] = generate_set(
        kind: :spirit_animals,
        entries: Motifs::Catalog.spirit_animal_entries
      )

      success(generated)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :theme, :ensure_only, :variants, :lore_only, :images_only, :only_slugs, :limit

    def generate_set(kind:, entries: [])
      results = []
      entries = apply_filters(entries)
      entries.each do |entry|
        upsert_motif(kind: kind, entry: entry)
        # Ensure lore exists (JSON) alongside images
        begin
          lore_status = ensure_lore(kind: kind, entry: entry)
          results << { slug: entry[:slug], aspect_ratio: "lore", status: lore_status[:status], path: lore_status[:path] }
        rescue StandardError => e
          results << { slug: entry[:slug], aspect_ratio: "lore", status: "error", error: e.message }
        end

        # Lore-only mode
        unless images_only
          # already handled above via ensure_lore
        end

        next if lore_only

        variants.each do |aspect_ratio|
          out_path = output_path_for(kind: kind, slug: entry[:slug], aspect_ratio: aspect_ratio)
          if ensure_only && File.exist?(out_path)
            # Ensure DB paths/URLs are recorded even when file already exists
            record_image(kind: kind, slug: entry[:slug], aspect_ratio: aspect_ratio, abs_path: out_path)
            results << { slug: entry[:slug], aspect_ratio: aspect_ratio, status: "present", path: out_path }
            next
          end

          FileUtils.mkdir_p(File.dirname(out_path))

          prompt = build_prompt(kind: kind, name: entry[:name], description: entry[:description])
          gen = Gemini::ImageGenerationService.call(
            prompt: prompt,
            aspect_ratio: aspect_ratio,
            output_path: out_path,
            provider: ENV["GEMINI_MOTIFS_PROVIDER"].presence
          )

          if gen.failure?
            results << { slug: entry[:slug], aspect_ratio: aspect_ratio, status: "error", error: gen.error&.message }
            next
          end

          # Best-effort convert to JPEG for smaller size
          final_path = out_path
          begin
            jpg_path = out_path.sub(/\.png\z/i, ".jpg")
            conv = Images::OptimizeService.call(path: out_path, output_path: jpg_path, format: "jpg", quality: 85)
            if conv.success?
              FileUtils.rm_f(out_path) if out_path.casecmp(jpg_path) != 0
              final_path = conv.value[:output_path]
            end
          rescue StandardError
          end

          record_image(kind: kind, slug: entry[:slug], aspect_ratio: aspect_ratio, abs_path: final_path)
          results << { slug: entry[:slug], aspect_ratio: aspect_ratio, status: "generated", path: final_path }
        end
      end
      results
    end

    def sanitize_theme(t)
      t.to_s.downcase.strip.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-").presence || DEFAULT_THEME
    end

    def normalize_only(val)
      return nil if val.nil?
      list = Array(val).join(",")
      slugs = list.split(/[,\s]+/).map { |s| s.to_s.strip }.reject(&:blank?).map { |n| Motifs::Catalog.to_slug(n) }
      slugs.presence
    end

    def apply_filters(entries)
      out = entries
      if only_slugs
        set = only_slugs.to_set
        out = out.select { |e| set.include?(e[:slug]) }
      end
      if limit && limit > 0
        out = out.first(limit)
      end
      out
    end

    def output_path_for(kind:, slug:, aspect_ratio:)
      variant_suffix = case aspect_ratio.to_s
      when "16:9" then "16x9"
      when "1:1" then "1x1"
      when "1:1" then "1x1"
      when "9:16" then "9x16"
      else aspect_ratio.to_s.tr(":", "x")
      end
      base_dir = Rails.root.join("public", "library", kind.to_s, theme)
      # We track .jpg as the canonical output to avoid re-generation due to PNG->JPG conversion
      File.join(base_dir, "#{slug}-#{variant_suffix}.jpg")
    end

    def build_prompt(kind:, name:, description:)
      subject = if kind.to_s == "archetypes"
        "Archetype: #{name}"
      else
        "Spirit Animal: #{name}"
      end

      <<~PROMPT.squish
        TecHub motif artwork for "#{subject}".
        Create a high-quality, abstract, emblematic illustration that conveys: #{description}.
        Style: consistent TecHub visual language; no text or logos; safe edges; overlay-friendly; rich gradients and geometric forms.
        Composition: centered emblem on subtle tech-themed background.
        Output: illustration only.
      PROMPT
    end

    def lore_path_for(kind:, slug:)
      base_dir = Rails.root.join("public", "library", kind.to_s, theme)
      File.join(base_dir, "#{slug}.json")
    end

    def ensure_lore(kind:, entry:)
      path = lore_path_for(kind: kind, slug: entry[:slug])
      if ensure_only && File.exist?(path)
        begin
          payload = JSON.parse(File.read(path))
        rescue StandardError
          payload = {}
        end
        persist_lore(kind: kind, entry: entry, payload: payload)
        return { status: "present", path: path }
      end
      return { status: "present", path: path } if File.exist?(path)

      # Generate structured lore JSON (short/long) via Gemini text API
      begin
        lore = Motifs::GenerateLoreService.call(
          name: entry[:name],
          description: entry[:description]
        )
      rescue StandardError
        lore = nil
      end

      if lore.nil? || (lore.respond_to?(:failure?) && lore.failure?)
        # Fallback minimal lore using catalog description
        payload = { name: entry[:name], slug: entry[:slug], short_lore: entry[:description].to_s.first(140), long_lore: entry[:description].to_s }
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(payload))
        persist_lore(kind: kind, entry: entry, payload: payload)
        { status: "generated_fallback", path: path }
      else
        payload = lore.value.merge({ name: entry[:name], slug: entry[:slug] })
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(payload))
        persist_lore(kind: kind, entry: entry, payload: payload)
        { status: "generated", path: path }
      end
    end

    def upsert_motif(kind:, entry:)
      rec = Motif.find_or_initialize_by(kind: kind.to_s.singularize, slug: entry[:slug], theme: theme)
      rec.name = entry[:name]
      rec.save!
    rescue StandardError
    end

    def persist_lore(kind:, entry:, payload: {})
      rec = Motif.find_or_initialize_by(kind: kind.to_s.singularize, slug: entry[:slug], theme: theme)
      rec.name = entry[:name]
      short_val = payload.is_a?(Hash) ? (payload["short_lore"] || payload[:short_lore]) : nil
      long_val  = payload.is_a?(Hash) ? (payload["long_lore"]  || payload[:long_lore])  : nil
      rec.short_lore = short_val.to_s.presence || rec.short_lore
      rec.long_lore  = long_val.to_s.presence  || rec.long_lore
      rec.save!
    rescue StandardError
    end

    def record_image(kind:, slug:, aspect_ratio:, abs_path:)
      rec = Motif.find_by(kind: kind.to_s.singularize, slug: slug, theme: theme)
      return unless rec

      # Store public-relative path for local serving fallback
      public_path = abs_path.to_s.sub(Rails.root.join("public").to_s, "")
      if aspect_ratio.to_s == "1:1"
        rec.image_1x1_path = public_path
      elsif aspect_ratio.to_s == "16:9"
        rec.image_16x9_path = public_path
      end

      # Upload to object storage in production (or when explicitly enabled) and persist CDN URL
      if upload_enabled?
        begin
          if File.exist?(abs_path.to_s)
            upload = Storage::ActiveStorageUploadService.call(
              path: abs_path.to_s,
              content_type: content_type_for_ext(File.extname(abs_path.to_s)),
              filename: File.basename(abs_path.to_s)
            )
            if upload.success?
              url = upload.value[:public_url]
              if aspect_ratio.to_s == "1:1"
                rec.image_1x1_url = url
              elsif aspect_ratio.to_s == "16:9"
                rec.image_16x9_url = url
              end
            end
          end
        rescue StandardError
          # best-effort; keep local path fallback
        end
      end

      rec.save!
    rescue StandardError
    end

    def upload_enabled?
      flag = ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase
      [ "1", "true", "yes" ].include?(flag) || Rails.env.production?
    end

    def content_type_for_ext(ext)
      case ext.to_s.downcase
      when ".jpg", ".jpeg" then "image/jpeg"
      else "image/png"
      end
    end
  end
end
