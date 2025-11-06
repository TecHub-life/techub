require "uri"

module ProfileShowcaseHelper
  VARIANT_STYLES = {
    "plain" => "bg-white/95 border-slate-200 dark:bg-slate-900/90 dark:border-slate-700 text-slate-900 dark:text-slate-100",
    "rainbow" => "bg-gradient-to-r from-rose-500 via-violet-500 to-sky-500 text-white border-transparent",
    "animated" => "bg-slate-900 text-slate-100 border-slate-800 shadow-lg shadow-slate-900/30 motion-safe:animate-pulse",
    "outline" => "bg-white border-2 border-indigo-400 text-slate-900 dark:bg-slate-900 dark:text-slate-100",
    "glass" => "bg-white/10 text-white border-white/20 backdrop-blur-lg",
    "mono" => "bg-slate-900 text-slate-100 border-slate-700"
  }.freeze

  SHAPE_CLASSES = {
    "pill" => "rounded-full",
    "card" => "rounded-[1.75rem]",
    "rounded" => "rounded-2xl"
  }.freeze

  STYLE_PREFIXES = %w[fa-solid fa-regular fa-light fa-thin fa-duotone fa-sharp fa-brands fa-classic].freeze
  BRAND_ICON_HINTS = %w[github gitlab twitter x instagram linkedin youtube spotify discord twitch npm docker slack reddit mastodon bluesky behance dribbble medium product-hunt stack-overflow stackexchange facebook soundcloud npmjs notion figma].freeze

  def showcase_style_classes(item, compact: false)
    variant = item.respond_to?(:applied_style_variant) ? item.applied_style_variant : "plain"
    shape = item.respond_to?(:applied_style_shape) ? item.applied_style_shape : "rounded"
    base = %w[rounded-2xl border shadow-sm transition duration-300 hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500 w-full mx-auto]
    base << (compact ? "max-w-xl" : "max-w-2xl")
    base << VARIANT_STYLES.fetch(variant, VARIANT_STYLES["plain"])
    base << SHAPE_CLASSES.fetch(shape, SHAPE_CLASSES["rounded"])
    base.join(" ")
  end

  def showcase_item_kind(item)
    case item
    when ProfileLink then "Link"
    when ProfileAchievement then "Achievement"
    when ProfileExperience then "Experience"
    else
      item.class.name.demodulize
    end
  end

  def showcase_item_title(item)
    if item.is_a?(ProfileLink)
      item.label
    elsif item.respond_to?(:title)
      item.title
    else
      item.try(:name) || item.to_s
    end
  end

  def showcase_item_subtitle(item)
    case item
    when ProfileLink
      item.subtitle.presence
    when ProfileAchievement
      item.description.presence
    when ProfileExperience
      [ item.organization, item.location ].compact.join(" · ").presence
    end
  end

  def showcase_item_meta_lines(item, preferences)
    case item
    when ProfileLink
      host = link_host(item.url)
      host ? [ host ] : []
    when ProfileAchievement
      lines = []
      formatted = formatted_achievement_date(item, preferences)
      lines << formatted if formatted.present?
      lines.concat(achievement_timestamp_lines(item, preferences))
      host = link_host(item.url)
      lines << host if host.present?
      lines
    when ProfileExperience
      lines = []
      range = experience_range(item)
      lines << range if range.present?
      lines << item.description if item.description.present?
      lines
    else
      []
    end
  end

  def experience_range(experience)
    start_text = format_month(experience.started_on)
    end_text = experience.current_role? ? "Present" : format_month(experience.ended_on)
    [ start_text, end_text ].compact.join(" – ")
  end

  def showcase_event_for(item)
    case item
    when ProfileLink then "profile_link_clicked"
    when ProfileAchievement then "profile_achievement_clicked"
    when ProfileExperience then "profile_experience_clicked"
    else
      "profile_item_clicked"
    end
  end

  def achievement_timestamp_lines(achievement, preference)
    return [] unless achievement.occurred_at.present? || achievement.occurred_on.present?

    lines = []
    formatted = formatted_achievement_date(achievement, preference)
    lines << formatted if formatted.present?

    time_mode = preference.achievements_time_display
    time_mode = "local" if time_mode.blank? || time_mode == "profile_default"

    if achievement.occurred_at.present?
      case time_mode
      when "relative"
        lines << relative_time_phrase(achievement.occurred_at)
      when "utc"
        lines << achievement.occurred_at.utc.strftime("%Y/%m/%d %H:%M UTC")
      else
        zone = achievement.timezone.presence || "Australia/Melbourne"
        lines << "#{achievement.occurred_at.in_time_zone(zone).strftime('%Y/%m/%d %H:%M')} #{zone}"
        if preference.achievements_dual_time?
          lines << achievement.occurred_at.utc.strftime("%Y/%m/%d %H:%M UTC")
        end
      end
    end
    lines
  end

  def formatted_achievement_date(achievement, preference)
    date = achievement.occurred_on || achievement.occurred_at&.to_date
    return nil unless date

    mode = achievement.date_display_mode
    mode = preference.achievements_date_format if mode.blank? || mode == "profile_default"

    case mode
    when "dd_mm_yyyy"
      date.strftime("%d/%m/%Y")
    when "relative"
      source_time = achievement.occurred_at || date.to_time
      relative_time_phrase(source_time)
    else
      date.strftime("%Y/%m/%d")
    end
  end

  def showcase_item_icon(item)
    if item.is_a?(ProfileLink)
      classes = safe_icon_classes(item.fa_icon)
      return content_tag(:i, "", class: classes, aria: { hidden: true }) if classes.present?
      content_tag(:span, "🔗", aria: { hidden: true })
    elsif item.is_a?(ProfileAchievement)
      classes = safe_icon_classes(item.fa_icon)
      return content_tag(:i, "", class: classes, aria: { hidden: true }) if classes.present?
      content_tag(:span, "🏅", aria: { hidden: true })
    elsif item.is_a?(ProfileExperience)
      content_tag(:span, "🧭", aria: { hidden: true })
    end
  end

  private

  def safe_icon_classes(raw)
    return if raw.blank?

    tokens = raw.to_s.split(/[\s,]+/).map(&:strip).select { |token| token.match?(/^[a-z0-9\-_]+$/i) }
    return if tokens.empty?

    tokens.unshift("fa") unless tokens.include?("fa")

    unless tokens.any? { |token| STYLE_PREFIXES.include?(token) }
      inferred_style = infer_style_for(tokens)
      tokens.insert(1, inferred_style)
    end

    tokens.uniq.join(" ")
  end

  def infer_style_for(tokens)
    name_token = tokens.find { |token| token.start_with?("fa-") && !STYLE_PREFIXES.include?(token) && token != "fa" }
    icon_name = name_token.to_s.sub(/\Afa-/, "")
    if BRAND_ICON_HINTS.any? { |hint| icon_name.include?(hint) }
      "fa-brands"
    else
      "fa-solid"
    end
  end

  def link_host(url)
    return if url.blank?
    host = URI.parse(url).host rescue nil
    host&.sub(/^www\./, "")
  end

  def format_month(date)
    date&.strftime("%b %Y")
  end

  def relative_time_phrase(time)
    if Time.current >= time
      "#{time_ago_in_words(time)} ago"
    else
      "in #{distance_of_time_in_words(Time.current, time)}"
    end
  end
end
