class PagesController < ApplicationController
  def home
    # Landing page - no profile data needed
  end

  def directory
    @layout = params[:layout].presence_in(%w[compact comfortable single]) || "comfortable"
    @q = params[:q].to_s.strip
    # Support multiple tags via `tags` (CSV or array) or legacy `tag`
    raw_tags = params[:tags]
    if raw_tags.is_a?(Array)
      @tags = raw_tags.map { |t| t.to_s.downcase.strip }.reject(&:blank?).uniq
    else
      csv = raw_tags.presence || params[:tag].to_s
      @tags = csv.to_s.split(/[,\s]+/).map { |t| t.downcase.strip }.reject(&:blank?).uniq
    end
    @language = params[:language].to_s.strip.downcase
    @hireable = ActiveModel::Type::Boolean.new.cast(params[:hireable])
    @mine = ActiveModel::Type::Boolean.new.cast(params[:mine])
    @min_followers = params[:min_followers].to_i if params[:min_followers].present?
    @active = ActiveModel::Type::Boolean.new.cast(params[:active])
    @archetype = params[:archetype].to_s.strip
    @spirit = params[:spirit].to_s.strip
    @page = params[:page].to_i
    @page = 1 if @page < 1
    default_per = case @layout
    when "single" then 8
    when "comfortable" then 16
    else 24
    end
    @per_page = (params[:per_page] || default_per).to_i.clamp(1, 60)
    offset = (@page - 1) * @per_page

    scope = Profile.where(last_pipeline_status: [ "success", "partial_success" ]).includes(:profile_assets, :profile_card)
    if @q.present?
      scope = scope.where("profiles.login LIKE :q OR profiles.name LIKE :q", q: "%#{@q}%")
    end
    if @tags.any?
      likes = @tags.map { |_| "lower(profile_cards.tags) LIKE ?" }.join(" OR ")
      vals = @tags.map { |t| "%\"#{t}\"%" }
      scope = scope.joins(:profile_card).where(likes, *vals)
    end
    if @archetype.present?
      scope = scope.joins(:profile_card).where("profile_cards.archetype = ?", @archetype)
    end
    if @spirit.present?
      scope = scope.joins(:profile_card).where("profile_cards.spirit_animal = ?", @spirit)
    end
    if @language.present?
      scope = scope.joins(:profile_languages).where("lower(profile_languages.name) = ?", @language)
    end
    if @hireable
      scope = scope.where(hireable: true)
    end
    if @min_followers && @min_followers > 0
      scope = scope.where("followers >= ?", @min_followers)
    end
    if @active
      scope = scope.joins(:profile_activity).where("profile_activities.last_active > ?", 30.days.ago)
    end
    if @mine
      uid = current_user&.id || session[:current_user_id]
      scope = scope.joins(:profile_ownerships).where(profile_ownerships: { user_id: uid }) if uid.present?
    end
    # Build tag cloud (from current successful profiles only)
    cloud_source = Profile.joins(:profile_card).where(last_pipeline_status: [ "success", "partial_success" ]).pluck("profile_cards.tags")
    @tag_cloud = cloud_source.flatten.map { |t| t.to_s.downcase.strip }.reject(&:blank?).tally.sort_by { |(_t, c)| -c }.first(40)

    @total = scope.count
    @profiles = scope.order(updated_at: :desc).limit(@per_page).offset(offset)

    @has_next = (@page * @per_page) < @total
    @has_prev = @page > 1
  end

  def gallery
    # Public gallery: opted-in profiles with AI-generated assets in their generated folder
    @profiles = Profile.where(ai_art_opt_in: true).includes(:profile_assets).limit(500)
    @items = []
    @profiles.each do |p|
      base = Rails.root.join("public", "generated", p.login)
      next unless Dir.exist?(base)
      Dir[base.join("avatar-*.{jpg,jpeg,png}").to_s].first(8).each do |path|
        @items << { login: p.login, kind: File.basename(path), url: "/generated/#{p.login}/#{File.basename(path)}" }
      end
    end
  end

  def motifs
    redirect_to archetypes_path
  end

  def archetypes
    @q = params[:q].to_s.strip.downcase
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @per_page = (params[:per_page] || 12).to_i.clamp(6, 48)

    # Get profile counts per archetype
    rows = Profile.joins(:profile_card).where(last_pipeline_status: "success").pluck("profile_cards.archetype")
    counts = Hash.new(0)
    rows.each { |arch| counts[arch] += 1 if arch.present? }

    # Build catalog from Motifs::Catalog with counts and DB records
    all_archetypes = Motifs::Catalog.archetypes.map do |name, desc|
      slug = Motifs::Catalog.to_slug(name)
      rec = Motif.find_by(kind: "archetype", theme: "core", slug: slug)
      {
        name: name,
        description: desc,
        slug: slug,
        count: counts[name] || 0,
        short_lore: rec&.short_lore,
        long_lore: rec&.long_lore,
        image_url: rec&.image_1x1_url
      }
    end

    # Filter by search query
    if @q.present?
      all_archetypes = all_archetypes.select { |a| a[:name].downcase.include?(@q) || a[:description].downcase.include?(@q) || a[:short_lore].to_s.downcase.include?(@q) }
    end

    # Pagination
    @total = all_archetypes.length
    offset = (@page - 1) * @per_page
    @archetypes = all_archetypes[offset, @per_page] || []
    @has_next = (@page * @per_page) < @total
    @has_prev = @page > 1
  end

  def spirit_animals
    @q = params[:q].to_s.strip.downcase
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @per_page = (params[:per_page] || 12).to_i.clamp(6, 48)

    # Get profile counts per spirit animal
    rows = Profile.joins(:profile_card).where(last_pipeline_status: "success").pluck("profile_cards.spirit_animal")
    counts = Hash.new(0)
    rows.each { |spirit| counts[spirit] += 1 if spirit.present? }

    # Build catalog from Motifs::Catalog with counts and DB records
    all_spirit_animals = Motifs::Catalog.spirit_animals.map do |name, desc|
      slug = Motifs::Catalog.to_slug(name)
      rec = Motif.find_by(kind: "spirit_animal", theme: "core", slug: slug)
      {
        name: name,
        description: desc,
        slug: slug,
        count: counts[name] || 0,
        short_lore: rec&.short_lore,
        long_lore: rec&.long_lore,
        image_url: rec&.image_1x1_url
      }
    end

    # Filter by search query
    if @q.present?
      all_spirit_animals = all_spirit_animals.select { |s| s[:name].downcase.include?(@q) || s[:description].downcase.include?(@q) || s[:short_lore].to_s.downcase.include?(@q) }
    end

    # Pagination
    @total = all_spirit_animals.length
    offset = (@page - 1) * @per_page
    @spirit_animals = all_spirit_animals[offset, @per_page] || []
    @has_next = (@page * @per_page) < @total
    @has_prev = @page > 1
  end

  def leaderboards; end

  def submit; end

  def faq; end

  def analytics; end

  def autocomplete
    field = params[:field]
    query = params[:q].to_s.downcase

    results = case field
    when "username"
      Profile.where("lower(login) LIKE ? OR lower(name) LIKE ?", "%#{query}%", "%#{query}%")
             .limit(10)
             .pluck(:login, :name)
             .map { |login, name| { value: login, label: "#{name} (@#{login})" } }
    when "tag"
      Profile.joins(:profile_card)
             .pluck("profile_cards.tags")
             .flatten
             .uniq
             .select { |t| t.to_s.downcase.include?(query) }
             .first(10)
             .map { |t| { value: t, label: t } }
    when "language"
      ProfileLanguage.where("lower(name) LIKE ?", "%#{query}%")
                     .distinct
                     .limit(10)
                     .pluck(:name)
                     .map { |l| { value: l, label: l } }
    else
      []
    end

    render json: { results: results }
  end
end
