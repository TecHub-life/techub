module Motifs
  module Catalog
    module_function

    def archetypes
      @archetypes ||= [
        [ "The Innocent", "Optimistic beginner’s mind; values simplicity and sincerity." ],
        [ "The Everyman", "Grounded, relatable collaborator who keeps teams steady." ],
        [ "The Hero", "Steps up under pressure; ships ambitious work against odds." ],
        [ "The Outlaw", "Breaks conventions to unlock bold new approaches." ],
        [ "The Explorer", "Curious pathfinder; thrives on discovery and breadth." ],
        [ "The Creator", "Imagination and craft; turns ideas into polished systems." ],
        [ "The Ruler", "Sets direction and standards; creates clarity for others." ],
        [ "The Magician", "Translates complexity into seamless experiences; makes hard things feel easy." ],
        [ "The Lover", "Designs for people first; warmth, care, and resonance." ],
        [ "The Caregiver", "Stability and support; invests in docs, tests, and teams." ],
        [ "The Jester", "Playful energy; energizes teams and sparks creativity." ],
        [ "The Sage", "Seeks truth and signal; mentors with hard-won insight." ]
      ]
    end

    def spirit_animals
      @spirit_animals ||= [
        [ "Danger Noodle", "Playful serpent spirit; quick, clever, and a little chaotic." ],
        [ "Wedge-tailed Eagle", "High vantage and precision; surveys systems end-to-end." ],
        [ "Platypus", "Unorthodox but effective; thrives across disciplines." ],
        [ "Kangaroo", "Powerful bursts; leaps milestones with momentum." ],
        [ "Dingo", "Adaptable problem-solver; strong in a pack or solo." ],
        [ "Saltwater Crocodile", "Patient strategist; strikes decisively when timing is right." ],
        [ "Redback Spider", "Elegant webs; builds resilient networks and edge cases." ],
        [ "Cassowary", "Bold guardian; protects boundaries and performance budgets." ],
        [ "Koala", "Calm focus; steady craftsmanship and reliability." ],
        [ "Quokka", "Delight-forward; lifts team morale and UX polish." ],
        [ "Great White Shark", "Relentless finisher; relentless on critical paths." ],
        [ "Tasmanian Devil", "Scrappy executor; unblocks gnarly issues fast." ],
        [ "Emu", "Fast and determined; keeps shipping forward." ],
        [ "Frilled-neck Lizard", "Signals clearly; excels at protective interfaces." ],
        [ "Blue-ringed Octopus", "Tiny yet potent; minimal code, maximum impact." ],
        [ "Echidna", "Spiky but sweet; defensive coding with charm." ],
        [ "Sugar Glider", "Lightweight and agile; glides between contexts." ],
        [ "Magpie", "Finds shiny signal; curates the best patterns." ],
        [ "Goanna", "Sun-powered refactors; warms up then moves decisively." ],
        [ "Taipan", "Lightning-fast; refactors with surgical precision." ],
        [ "Box Jellyfish", "Invisible but formidable; sees edge cases others miss." ],
        [ "Kookaburra", "Laughs off bugs; keeps spirits high through cycles." ],
        [ "Wallaby", "Sure-footed explorer; balances speed with care." ],
        [ "Bilby", "Night-shift artisan; quietly crafts exquisite features." ],
        [ "Bandicoot", "Nimble digger; uncovers root causes quickly." ],
        [ "Wombat", "Solid foundation builder; loves clean, sturdy infra." ],
        [ "Tiger Snake", "Stripe-smart; patterns, tests, and tidy APIs." ],
        [ "Stonefish", "Still waters, sharp spikes; protects systems from misuse." ],
        [ "Funnel-web Spider", "Defensive design; locks down security pathways." ],
        [ "Cockatoo", "Noisy when needed; calls attention to crucial issues." ],
        [ "Possum", "Resourceful survivor; thrives in complex legacy code." ],
        [ "Flying Fox", "Night navigator; maps systems across long distances." ]
      ]
    end

    def archetype_names
      archetypes.map(&:first)
    end

    def spirit_animal_names
      spirit_animals.map(&:first)
    end

    # Utility helpers for system artwork generation
    def to_slug(name)
      name.to_s.downcase.strip.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-")
    end

    def archetype_entries
      archetypes.map { |name, desc| { name: name, description: desc, slug: to_slug(name) } }
    end

    def spirit_animal_entries
      spirit_animals.map { |name, desc| { name: name, description: desc, slug: to_slug(name) } }
    end
  end
end
