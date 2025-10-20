# Ensure system motif artwork exists at boot in production-like environments.
# Best-effort: runs in background via Solid Queue when available; does nothing in test.

unless Rails.env.test?
  Rails.application.config.after_initialize do
    begin
      theme = ENV["MOTIFS_THEME"].presence || "core"
      # Skip when explicitly disabled
      next if ENV["MOTIFS_BOOTSTRAP"].to_s.downcase == "0"

      # Use job if defined, else run service inline (short set, idempotent)
      if defined?(Motifs::EnsureJob)
        Motifs::EnsureJob.perform_later(theme: theme)
      else
        Motifs::GenerateLibraryService.call(theme: theme, ensure_only: true)
      end
    rescue StandardError => e
      Rails.logger.warn("Motifs bootstrap failed: #{e.message}") rescue nil
    end
  end
end
