module Motifs
  class GenerateLoreService < ApplicationService
    DEFAULT_SCHEMA = {
      type: "object",
      properties: {
        short_lore: { type: "string" },
        long_lore:  { type: "string" }
      },
      required: [ "short_lore" ]
    }.freeze

    def initialize(motif:, overwrite: false, provider: nil)
      @motif = motif
      @overwrite = overwrite
      @provider = provider
    end

    def call
      return success(motif) if !overwrite && motif.short_lore.present? && motif.long_lore.present?

      prompt = build_prompt(motif)
      result = Gemini::StructuredOutputService.call(
        prompt: prompt,
        response_schema: DEFAULT_SCHEMA,
        provider: provider
      )
      return failure(result.error) if result.failure?

      payload = result.value
      motif.short_lore = payload["short_lore"].to_s.strip.presence || motif.short_lore
      motif.long_lore  = payload["long_lore"].to_s.strip.presence || motif.long_lore
      motif.save!
      success(motif)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :motif, :overwrite, :provider

    def build_prompt(motif)
      kind = motif.kind == "spirit_animal" ? "Spirit Animal" : "Archetype"
      base = <<~TXT
        Generate lore for a TecHub #{kind}.
        Name: #{motif.name}
        Slug: #{motif.slug}
        Theme: #{motif.theme}

        Audience: developers. Tone: concise, positive, credible.
        Constraints:
        - short_lore: one sentence (≤ 140 chars), plain text.
        - long_lore: 2–4 sentences, plain text, no markdown.
        Return JSON only matching the schema.
      TXT
      if motif.short_lore.present? && overwrite
        base << "\nCurrent short_lore (may be replaced): #{motif.short_lore}\n"
      end
      if motif.long_lore.present? && overwrite
        base << "Current long_lore (may be replaced): #{motif.long_lore}\n"
      end
      base
    end
  end
end
