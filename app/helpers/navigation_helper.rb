module NavigationHelper
  def nav_link_class(path)
    base = "transition hover:text-slate-900 dark:hover:text-slate-100"
    current_page?(path) ? "text-slate-900 dark:text-slate-100 font-semibold #{base}" : base
  end
end
