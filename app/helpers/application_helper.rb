module ApplicationHelper
  # Convert a relative path (or already absolute URL) into a full absolute URL.
  def absolute_url_for(path)
    return if path.blank?

    str = path.to_s
    return str if str.start_with?("http://", "https://")

    root = request.base_url
    normalized = str.start_with?("/") ? str : "/#{str}"
    "#{root}#{normalized}"
  end

  # Compute an absolute URL for an asset managed by the pipeline or served from /public.
  def full_asset_url(logical_path)
    relative = asset_path(logical_path)
    absolute_url_for(relative)
  rescue Sprockets::Rails::Helper::AssetNotFound
    absolute_url_for("/#{logical_path}".squeeze("/"))
  end

  def ui_input_class
    "block h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-900 placeholder-slate-400 shadow-sm transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100 dark:placeholder-slate-500"
  end

  def ui_textarea_class
    "block min-h-[5.5rem] w-full rounded-lg border border-slate-300 bg-white px-3 py-3 text-sm text-slate-900 placeholder-slate-400 shadow-sm transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-500 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100 dark:placeholder-slate-500"
  end

  def ui_select_class
    "#{ui_input_class} pr-10"
  end

  def ui_checkbox_class
    "h-5 w-5 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500 dark:border-slate-600"
  end

  def ui_primary_button_class
    "inline-flex h-11 items-center justify-center gap-2 rounded-full bg-slate-900 px-5 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-500 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-slate-200"
  end

  def ui_secondary_button_class
    "inline-flex h-11 items-center justify-center gap-2 rounded-full border border-slate-200 bg-white px-5 text-sm font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50 hover:border-slate-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-500 disabled:cursor-not-allowed disabled:opacity-60 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300 dark:hover:bg-slate-800"
  end

  def ui_file_input_class
    "block w-full text-sm text-slate-700 file:mr-4 file:rounded-full file:border-0 file:bg-slate-900 file:px-5 file:py-2.5 file:text-sm file:font-semibold file:text-white transition hover:file:bg-slate-800 dark:text-slate-300 dark:file:bg-slate-200 dark:file:text-slate-900"
  end
end
