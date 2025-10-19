class PagesController < ApplicationController
  def home
    # Landing page - no profile data needed
  end

  def directory
    @layout = params[:layout].presence_in(%w[compact comfortable single]) || "comfortable"
    @q = params[:q].to_s.strip
    @tag = params[:tag].to_s.strip.downcase
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

    scope = Profile.where(last_pipeline_status: "success").includes(:profile_assets, :profile_card)
    if @q.present?
      scope = scope.where("profiles.login LIKE :q OR profiles.name LIKE :q", q: "%#{@q}%")
    end
    if @tag.present?
      scope = scope.joins(:profile_card).where("lower(profile_cards.tags) LIKE ?", "%\"#{@tag}\"%")
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
    cloud_source = Profile.joins(:profile_card).where(last_pipeline_status: "success").pluck("profile_cards.tags")
    @tag_cloud = cloud_source.flatten.map { |t| t.to_s.downcase.strip }.reject(&:blank?).tally.sort_by { |(_t, c)| -c }.first(40)

    @total = scope.count
    @profiles = scope.order(updated_at: :desc).limit(@per_page).offset(offset)

    @has_next = (@page * @per_page) < @total
    @has_prev = @page > 1
  end

  def motifs
    # Canonical catalogs with counts from current successful profiles
    rows = Profile.joins(:profile_card).where(last_pipeline_status: "success").pluck("profile_cards.spirit_animal", "profile_cards.archetype")
    counts_spirit = Hash.new(0)
    counts_arch = Hash.new(0)
    rows.each do |spirit, arch|
      counts_spirit[spirit] += 1 if spirit.present?
      counts_arch[arch] += 1 if arch.present?
    end

    @archetype_catalog = Motifs::Catalog.archetypes.map do |name, desc|
      { name: name, description: desc, count: counts_arch[name] }
    end
    @spirit_catalog = Motifs::Catalog.spirit_animals.map do |name, desc|
      { name: name, description: desc, count: counts_spirit[name] }
    end
  end

  def leaderboards; end

  def submit; end

  def faq; end

  def analytics; end

  def docs
    root = Rails.root.join("docs")
    @path = params[:path].to_s
    # Build a simple index of markdown files
    @docs_index = Dir[root.join("**", "*.md")].map { |p| p.delete_prefix(root.to_s + "/") }.sort
    # Resolve the requested doc or default
    rel = @path.presence || "marketing-overview.md"
    target = root.join(rel)
    if target.to_s.start_with?(root.to_s) && File.exist?(target) && File.file?(target)
      @doc_title = rel
      @doc_markdown = File.read(target)
    end
  end

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
