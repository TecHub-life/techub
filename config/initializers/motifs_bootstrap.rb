# Ensure system motif artwork exists at boot in production-like environments.
# Best-effort: runs in background via Solid Queue when available; does nothing in test.

unless Rails.env.test?
  Rails.application.config.after_initialize do
    begin
      theme = ENV["MOTIFS_THEME"].presence || "core"
      # Skip when explicitly disabled
      next if ENV["MOTIFS_BOOTSTRAP"].to_s.downcase == "0"

      # Use job if defined, else run service inline (short set, idempotent)
      # Default: ensure lore only to avoid incurring image costs on boot
      lore_only = ENV["MOTIFS_BOOTSTRAP_IMAGES"].to_s.downcase == "0"
      if defined?(Motifs::EnsureJob) && !lore_only
        Motifs::EnsureJob.perform_later(theme: theme)
      else
        Motifs::GenerateLibraryService.call(theme: theme, ensure_only: true, lore_only: true)
      end
    rescue StandardError => e
      Rails.logger.warn("Motifs bootstrap failed: #{e.message}") rescue nil
    end
  end
end
