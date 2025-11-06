module NavigationHelper
  DESKTOP_LINK_CLASSES = "inline-flex items-center gap-2 rounded-full px-3 py-2 transition-colors duration-150 hover:text-slate-900 dark:hover:text-slate-100".freeze
  MOBILE_LINK_CLASSES  = "flex items-center justify-between rounded-lg px-3 py-2 transition-colors duration-150 hover:bg-slate-100 dark:hover:bg-slate-800".freeze

  def nav_link_to(label, path, active: nil, render_only: nil, **options)
    is_active = active.nil? ? (path.present? && current_page?(path)) : active
    classes = build_nav_classes(is_active)

    return classes if render_only == :classes

    link_to label, path, options.merge(class: classes)
  end

  def mobile_nav_link(label, path, active: nil, icon: nil, **options)
    is_active = active.nil? ? (path.present? && current_page?(path)) : active
    classes = build_mobile_classes(is_active)
    link_to path, options.merge(class: classes) do
      safe_join([
        (content_tag(:i, nil, class: "#{icon} text-sm opacity-70") if icon),
        content_tag(:span, label),
      ].compact, " ")
    end
  end

  def nav_link_with_icon(label, path, icon, **options)
    is_active = options.key?(:active) ? options.delete(:active) : (path.present? && current_page?(path))
    classes   = build_nav_classes(is_active)
    link_to path, options.merge(class: classes) do
      safe_join([
        content_tag(:i, nil, class: "#{icon} text-base"),
        content_tag(:span, label),
      ])
    end
  end

  def nav_dropdown_link(label, path, icon, active: false, **options)
    classes = "flex items-center gap-2 px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-slate-100"
    classes = "#{classes} bg-slate-100 text-slate-900 dark:bg-slate-800 dark:text-slate-100" if active
    link_to path, options.merge(class: classes) do
      safe_join([
        content_tag(:i, nil, class: "#{icon} text-sm"),
        content_tag(:span, label),
      ])
    end
  end

  private

  def build_nav_classes(active)
    "#{DESKTOP_LINK_CLASSES} #{active ? 'text-slate-900 dark:text-slate-100' : 'text-slate-600 dark:text-slate-300'}"
  end

  def build_mobile_classes(active)
    "#{MOBILE_LINK_CLASSES} #{active ? 'bg-slate-100 text-slate-900 dark:bg-slate-800 dark:text-slate-100' : 'text-slate-600 dark:text-slate-300'}"
  end
end
