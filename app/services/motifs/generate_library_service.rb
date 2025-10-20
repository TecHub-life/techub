module Motifs
  class GenerateLibraryService < ApplicationService
    DEFAULT_THEME = "core".freeze
    DEFAULT_VARIANTS = [ "16:9", "21:9" ].freeze # 16x9 primary, 21:9 approximates 3x1 banner

    def initialize(theme: DEFAULT_THEME, ensure_only: false, variants: DEFAULT_VARIANTS)
      @theme = sanitize_theme(theme)
      @ensure_only = !!ensure_only
      @variants = Array(variants).presence || DEFAULT_VARIANTS
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

    attr_reader :theme, :ensure_only, :variants

    def generate_set(kind:, entries: [])
      results = []
      entries.each do |entry|
        variants.each do |aspect_ratio|
          out_path = output_path_for(kind: kind, slug: entry[:slug], aspect_ratio: aspect_ratio)
          if ensure_only && File.exist?(out_path)
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

          results << { slug: entry[:slug], aspect_ratio: aspect_ratio, status: "generated", path: final_path }
        end
      end
      results
    end

    def sanitize_theme(t)
      t.to_s.downcase.strip.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-").presence || DEFAULT_THEME
    end

    def output_path_for(kind:, slug:, aspect_ratio:)
      variant_suffix = case aspect_ratio.to_s
      when "16:9" then "16x9"
      when "21:9" then "3x1"
      when "1:1" then "1x1"
      when "9:16" then "9x16"
      else aspect_ratio.to_s.tr(":", "x")
      end
      base_dir = Rails.root.join("public", "library", kind.to_s, theme)
      File.join(base_dir, "#{slug}-#{variant_suffix}.png")
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
  end
end
