class PagesController < ApplicationController
  def home
    # Landing page - no profile data needed
  end

  def directory
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
    @per_page = (params[:per_page] || 24).to_i.clamp(1, 60)
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
    # Aggregate counts for spirit animals and archetypes across successful profiles
    rows = Profile.joins(:profile_card).where(last_pipeline_status: "success").pluck("profile_cards.spirit_animal", "profile_cards.archetype")
    spirits = Hash.new(0)
    archetypes = Hash.new(0)
    rows.each do |spirit, arch|
      spirits[spirit] += 1 if spirit.present?
      archetypes[arch] += 1 if arch.present?
    end

    @spirits = spirits.sort_by { |(_k, v)| -v }
    @archetypes = archetypes.sort_by { |(_k, v)| -v }
  end

  def leaderboards; end

  def submit; end

  def faq; end

  def analytics; end

  def docs
    @marketing_overview = File.read(Rails.root.join("docs", "marketing-overview.md")) if File.exist?(Rails.root.join("docs", "marketing-overview.md"))
  end
end
