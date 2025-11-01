module Battles
  class SimulateService < ApplicationService
    # Type advantage system inspired by Pokemon
    # Archetypes have advantages/disadvantages against each other
    TYPE_ADVANTAGES = {
      "The Hero" => { strong_against: ["The Innocent", "The Everyman"], weak_against: ["The Outlaw", "The Magician"] },
      "The Outlaw" => { strong_against: ["The Hero", "The Ruler"], weak_against: ["The Sage", "The Caregiver"] },
      "The Explorer" => { strong_against: ["The Innocent", "The Lover"], weak_against: ["The Hero", "The Ruler"] },
      "The Creator" => { strong_against: ["The Everyman", "The Jester"], weak_against: ["The Outlaw", "The Explorer"] },
      "The Ruler" => { strong_against: ["The Everyman", "The Caregiver"], weak_against: ["The Outlaw", "The Magician"] },
      "The Magician" => { strong_against: ["The Hero", "The Ruler"], weak_against: ["The Sage", "The Creator"] },
      "The Lover" => { strong_against: ["The Jester", "The Caregiver"], weak_against: ["The Explorer", "The Sage"] },
      "The Caregiver" => { strong_against: ["The Innocent", "The Lover"], weak_against: ["The Outlaw", "The Ruler"] },
      "The Jester" => { strong_against: ["The Sage", "The Ruler"], weak_against: ["The Creator", "The Hero"] },
      "The Sage" => { strong_against: ["The Outlaw", "The Magician"], weak_against: ["The Jester", "The Innocent"] },
      "The Innocent" => { strong_against: ["The Sage", "The Jester"], weak_against: ["The Hero", "The Explorer"] },
      "The Everyman" => { strong_against: ["The Creator", "The Explorer"], weak_against: ["The Hero", "The Ruler"] }
    }.freeze

    # Spirit animals provide stat modifiers
    SPIRIT_ANIMAL_MODIFIERS = {
      "Danger Noodle" => { speed: 1.2, attack: 1.1 },
      "Wedge-tailed Eagle" => { attack: 1.3, defense: 0.9 },
      "Platypus" => { defense: 1.2, speed: 1.1 },
      "Kangaroo" => { speed: 1.3, attack: 1.1 },
      "Dingo" => { attack: 1.2, speed: 1.1 },
      "Saltwater Crocodile" => { defense: 1.3, attack: 1.2 },
      "Redback Spider" => { speed: 1.2, defense: 1.1 },
      "Cassowary" => { defense: 1.3, attack: 1.1 },
      "Koala" => { defense: 1.3, speed: 0.9 },
      "Quokka" => { speed: 1.2, defense: 1.1 },
      "Great White Shark" => { attack: 1.3, speed: 1.1 },
      "Tasmanian Devil" => { attack: 1.2, speed: 1.2 },
      "Emu" => { speed: 1.3, defense: 1.0 },
      "Frilled-neck Lizard" => { defense: 1.2, speed: 1.1 },
      "Blue-ringed Octopus" => { attack: 1.3, speed: 1.2 },
      "Echidna" => { defense: 1.3, attack: 0.9 },
      "Sugar Glider" => { speed: 1.3, defense: 0.9 },
      "Magpie" => { speed: 1.2, attack: 1.1 },
      "Goanna" => { attack: 1.2, defense: 1.1 },
      "Taipan" => { speed: 1.3, attack: 1.2 },
      "Box Jellyfish" => { speed: 1.2, defense: 1.2 },
      "Kookaburra" => { defense: 1.1, speed: 1.1 },
      "Wallaby" => { speed: 1.2, defense: 1.1 },
      "Bilby" => { attack: 1.1, speed: 1.2 },
      "Bandicoot" => { speed: 1.3, attack: 1.0 },
      "Wombat" => { defense: 1.3, attack: 0.9 },
      "Tiger Snake" => { attack: 1.2, speed: 1.2 },
      "Stonefish" => { defense: 1.3, attack: 1.1 },
      "Funnel-web Spider" => { defense: 1.2, attack: 1.2 },
      "Cockatoo" => { speed: 1.2, defense: 1.0 },
      "Possum" => { defense: 1.2, speed: 1.1 },
      "Flying Fox" => { speed: 1.2, attack: 1.1 },
      "Loftbubu" => { speed: 1.3, attack: 1.2, defense: 1.1 }
    }.freeze

    def initialize(challenger_id:, opponent_id:, battle: nil)
      @challenger_id = challenger_id
      @opponent_id = opponent_id
      @battle = battle
    end

    def call
      challenger = Profile.includes(:profile_card).find_by(id: @challenger_id)
      opponent = Profile.includes(:profile_card).find_by(id: @opponent_id)

      return failure(StandardError.new("Challenger profile not found")) unless challenger
      return failure(StandardError.new("Opponent profile not found")) unless opponent
      return failure(StandardError.new("Challenger has no card")) unless challenger.profile_card
      return failure(StandardError.new("Opponent has no card")) unless opponent.profile_card
      return failure(StandardError.new("Cannot battle yourself")) if challenger.id == opponent.id

      battle = @battle || Battle.create!(
        challenger_profile: challenger,
        opponent_profile: opponent,
        status: "in_progress"
      )

      simulate_battle(battle, challenger, opponent)

      success(battle)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :challenger_id, :opponent_id

    def simulate_battle(battle, challenger, opponent)
      challenger_card = challenger.profile_card
      opponent_card = opponent.profile_card

      # Calculate effective stats with spirit animal modifiers
      challenger_stats = calculate_effective_stats(challenger_card)
      opponent_stats = calculate_effective_stats(opponent_card)

      # Initialize HP (based on defense stat)
      challenger_hp = 100
      opponent_hp = 100

      battle.add_log_entry({
        type: "battle_start",
        message: "#{challenger.login} (#{challenger_card.archetype}) vs #{opponent.login} (#{opponent_card.archetype})"
      })

      # Check type advantage
      challenger_advantage = calculate_type_advantage(challenger_card.archetype, opponent_card.archetype)
      opponent_advantage = calculate_type_advantage(opponent_card.archetype, challenger_card.archetype)

      if challenger_advantage > 1.0
        battle.add_log_entry({
          type: "type_advantage",
          message: "#{challenger.login}'s #{challenger_card.archetype} has an advantage against #{opponent_card.archetype}!",
          multiplier: challenger_advantage
        })
      elsif opponent_advantage > 1.0
        battle.add_log_entry({
          type: "type_advantage",
          message: "#{opponent.login}'s #{opponent_card.archetype} has an advantage against #{challenger_card.archetype}!",
          multiplier: opponent_advantage
        })
      end

      # Determine who goes first (speed stat)
      attacker, defender = challenger_stats[:speed] >= opponent_stats[:speed] ? 
        [{ profile: challenger, card: challenger_card, stats: challenger_stats, hp: challenger_hp, advantage: challenger_advantage }, 
         { profile: opponent, card: opponent_card, stats: opponent_stats, hp: opponent_hp, advantage: opponent_advantage }] :
        [{ profile: opponent, card: opponent_card, stats: opponent_stats, hp: opponent_hp, advantage: opponent_advantage },
         { profile: challenger, card: challenger_card, stats: challenger_stats, hp: challenger_hp, advantage: challenger_advantage }]

      battle.add_log_entry({
        type: "speed_check",
        message: "#{attacker[:profile].login} moves first! (Speed: #{attacker[:stats][:speed].round(1)} vs #{defender[:stats][:speed].round(1)})"
      })

      turn = 0
      max_turns = 20 # Prevent infinite loops

      # Battle loop
      while attacker[:hp] > 0 && defender[:hp] > 0 && turn < max_turns
        turn += 1

        # Calculate damage
        damage = calculate_damage(attacker[:stats], defender[:stats], attacker[:advantage])
        defender[:hp] -= damage
        defender[:hp] = [defender[:hp], 0].max

        battle.add_log_entry({
          type: "attack",
          turn: turn,
          attacker: attacker[:profile].login,
          defender: defender[:profile].login,
          damage: damage.round(1),
          defender_hp: defender[:hp].round(1),
          special_move: attacker[:card].special_move
        })

        # Check for knockout
        if defender[:hp] <= 0
          battle.add_log_entry({
            type: "knockout",
            message: "#{defender[:profile].login} has been defeated!",
            winner: attacker[:profile].login
          })
          break
        end

        # Swap attacker and defender
        attacker, defender = defender, attacker
      end

      # Determine winner
      winner = attacker[:hp] > defender[:hp] ? attacker[:profile] : defender[:profile]
      final_challenger_hp = attacker[:profile].id == challenger.id ? attacker[:hp] : defender[:hp]
      final_opponent_hp = attacker[:profile].id == opponent.id ? attacker[:hp] : defender[:hp]

      battle.update!(
        status: "completed",
        winner_profile: winner,
        challenger_hp: final_challenger_hp.round,
        opponent_hp: final_opponent_hp.round
      )

      battle.add_log_entry({
        type: "battle_end",
        message: "#{winner.login} wins!",
        final_hp: {
          challenger: final_challenger_hp.round,
          opponent: final_opponent_hp.round
        }
      })

      battle.save!
    end

    def calculate_effective_stats(card)
      base_stats = {
        attack: card.attack.to_f,
        defense: card.defense.to_f,
        speed: card.speed.to_f
      }

      # Apply spirit animal modifiers
      if card.spirit_animal.present? && SPIRIT_ANIMAL_MODIFIERS[card.spirit_animal]
        modifiers = SPIRIT_ANIMAL_MODIFIERS[card.spirit_animal]
        base_stats[:attack] *= (modifiers[:attack] || 1.0)
        base_stats[:defense] *= (modifiers[:defense] || 1.0)
        base_stats[:speed] *= (modifiers[:speed] || 1.0)
      end

      base_stats
    end

    def calculate_type_advantage(attacker_type, defender_type)
      return 1.0 unless attacker_type.present? && defender_type.present?
      return 1.0 unless TYPE_ADVANTAGES[attacker_type]

      advantages = TYPE_ADVANTAGES[attacker_type]
      
      if advantages[:strong_against]&.include?(defender_type)
        1.5 # 50% damage bonus
      elsif advantages[:weak_against]&.include?(defender_type)
        0.75 # 25% damage reduction
      else
        1.0 # Neutral
      end
    end

    def calculate_damage(attacker_stats, defender_stats, type_advantage)
      # Base damage formula: (Attack / Defense) * random factor * type advantage
      base_damage = (attacker_stats[:attack] / [defender_stats[:defense], 1].max) * 10
      random_factor = 0.85 + (rand * 0.3) # Random between 0.85 and 1.15
      damage = base_damage * random_factor * type_advantage

      # Minimum damage of 5
      [damage, 5].max
    end
  end
end
