namespace :motifs do
  desc "Seed motifs from catalog (OVERWRITE=1 to overwrite lore/images)"
  task seed: :environment do
    overwrite = %w[1 true yes].include?(ENV["OVERWRITE"].to_s.downcase)
    created = 0
    updated = 0

    Motifs::Catalog.archetype_entries.each do |e|
      rec = Motif.find_or_initialize_by(kind: "archetype", theme: "core", slug: e[:slug])
      if rec.new_record?
        rec.name = e[:name]
        rec.short_lore = e[:description]
        rec.long_lore ||= nil
        rec.save!; created += 1
      elsif overwrite
        rec.name = e[:name]
        rec.short_lore = e[:description]
        rec.save!; updated += 1
      end
    end

    Motifs::Catalog.spirit_animal_entries.each do |e|
      rec = Motif.find_or_initialize_by(kind: "spirit_animal", theme: "core", slug: e[:slug])
      if rec.new_record?
        rec.name = e[:name]
        rec.short_lore = e[:description]
        rec.long_lore ||= nil
        rec.save!; created += 1
      elsif overwrite
        rec.name = e[:name]
        rec.short_lore = e[:description]
        rec.save!; updated += 1
      end
    end

    puts "Motifs seed complete — created=#{created}, updated=#{updated}, overwrite=#{overwrite}"
  end
end
