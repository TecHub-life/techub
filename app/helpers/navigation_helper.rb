module NavigationHelper
  def nav_link_class(path)
    base = "flex items-center gap-2 transition-colors duration-200 hover:text-slate-900 dark:hover:text-slate-100"
    current_page?(path) ? "text-slate-900 dark:text-slate-100 font-semibold border-b-2 border-blue-600 dark:border-blue-400 pb-0.5 #{base}" : base
  end
end
