module Ops
  class MotifsController < BaseController
    before_action :set_motif, only: [ :edit, :update, :destroy ]

    def index
      @q = params[:q].to_s.strip
      scope = Motif.order(:kind, :name)
      scope = scope.where("name ILIKE ? OR slug ILIKE ?", "%#{@q}%", "%#{@q}%") if @q.present?
      @motifs = scope.limit(500)
    end

    def seed_from_catalog
      overwrite = params[:overwrite].to_s == "1"
      created = 0
      updated = 0
      Motifs::Catalog.archetype_entries.each do |e|
        c, u = ensure_motif!("archetype", e, overwrite: overwrite)
        created += c; updated += u
      end
      Motifs::Catalog.spirit_animal_entries.each do |e|
        c, u = ensure_motif!("spirit_animal", e, overwrite: overwrite)
        created += c; updated += u
      end
      redirect_to ops_motifs_path, notice: "Seed complete (created=#{created}, updated=#{updated}, overwrite=#{overwrite})"
    end

    def new
      @motif = Motif.new(kind: params[:kind].presence || "archetype", theme: "core")
    end

    def create
      @motif = Motif.new(motif_params)
      assign_slug
      handle_uploads(@motif)
      if @motif.save
        redirect_to ops_motifs_path, notice: "Motif created"
      else
        flash.now[:alert] = @motif.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @motif.assign_attributes(motif_params)
      assign_slug
      handle_uploads(@motif)
      if @motif.save
        redirect_to ops_motifs_path, notice: "Motif updated"
      else
        flash.now[:alert] = @motif.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @motif.destroy
      redirect_to ops_motifs_path, notice: "Motif deleted"
    end

    def generate_missing_lore
      overwrite = params[:overwrite].to_s == "1"
      count = 0
      Motif.order(:kind, :name).find_each do |m|
        next if !overwrite && m.short_lore.present? && m.long_lore.present?
        res = Motifs::GenerateLoreService.call(motif: m, overwrite: overwrite)
        count += 1 if res.success?
      end
      redirect_to ops_motifs_path, notice: "Lore generation complete (updated #{count})"
    end

    private

    def set_motif
      @motif = Motif.find(params[:id])
    end

    def motif_params
      params.require(:motif).permit(:kind, :name, :slug, :theme, :short_lore, :long_lore, :image_1x1_url, :image_16x9_url)
    end

    def assign_slug
      if @motif.slug.blank? && @motif.name.present?
        @motif.slug = Motifs::Catalog.to_slug(@motif.name)
      end
    end

    def handle_uploads(motif)
      file_1x1 = params.dig(:motif, :image_1x1_file)
      if file_1x1.respond_to?(:path)
        content_type = Marcel::MimeType.for(file_1x1.path)
        unless content_type.to_s.start_with?("image/")
          motif.errors.add(:base, "Image 1x1 must be an image file")
          return
        end
        up = Storage::ActiveStorageUploadService.call(path: file_1x1.path, content_type: content_type, filename: file_1x1.original_filename)
        motif.image_1x1_url = up.value[:public_url] if up.success?
      end

      file_16x9 = params.dig(:motif, :image_16x9_file)
      if file_16x9.respond_to?(:path)
        content_type = Marcel::MimeType.for(file_16x9.path)
        unless content_type.to_s.start_with?("image/")
          motif.errors.add(:base, "Image 16x9 must be an image file")
          return
        end
        up = Storage::ActiveStorageUploadService.call(path: file_16x9.path, content_type: content_type, filename: file_16x9.original_filename)
        motif.image_16x9_url = up.value[:public_url] if up.success?
      end
    end

    def ensure_motif!(kind, entry, overwrite: false)
      slug = entry[:slug]
      name = entry[:name]
      rec = Motif.find_or_initialize_by(kind: kind, theme: "core", slug: slug)
      if rec.new_record?
        rec.name = name
        rec.short_lore = entry[:description]
        rec.save!
        return [ 1, 0 ]
      elsif overwrite
        rec.name = name
        rec.short_lore = entry[:description]
        rec.save!
        return [ 0, 1 ]
      end
      [ 0, 0 ]
    end
  end
end
