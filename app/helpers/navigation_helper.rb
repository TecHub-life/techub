module NavigationHelper
  def nav_link_class(path)
    base = "flex items-center gap-2 transition-transform duration-200 ease-in-out hover:scale-105 hover:text-slate-900 dark:hover:text-slate-100"
    current_page?(path) ? "text-slate-900 dark:text-slate-100 font-semibold #{base}" : base
  end
end
