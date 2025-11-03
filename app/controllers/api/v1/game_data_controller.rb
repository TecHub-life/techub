module Api
  module V1
    class GameDataController < ApplicationController
      # GET /api/v1/game-data/archetypes
      def archetypes
        render json: {
          archetypes: ARCHETYPES,
          type_chart: TYPE_ADVANTAGES
        }
      end

      # GET /api/v1/game-data/spirit-animals
      def spirit_animals
        render json: {
          spirit_animals: SPIRIT_ANIMALS
        }
      end

      # GET /api/v1/game-data/all
      def all
        render json: {
          archetypes: ARCHETYPES,
          type_chart: TYPE_ADVANTAGES,
          spirit_animals: SPIRIT_ANIMALS,
          archetype_abilities: ARCHETYPE_ABILITIES,
          mechanics: BATTLE_MECHANICS
        }
      end

      # GET /api/v1/game-data/abilities
      def abilities
        render json: {
          archetype_abilities: ARCHETYPE_ABILITIES
        }
      end

      private

      # 12 Archetypes
      ARCHETYPES = [
        "The Magician",
        "The Hero",
        "The Rebel",
        "The Explorer",
        "The Sage",
        "The Innocent",
        "The Creator",
        "The Ruler",
        "The Caregiver",
        "The Everyperson",
        "The Jester",
        "The Lover"
      ]

      # Type Advantage Chart (Pokémon-style)
      TYPE_ADVANTAGES = {
        "The Magician" => {
          strong_against: [ "The Sage", "The Creator" ],
          weak_against: [ "The Rebel", "The Hero" ]
        },
        "The Hero" => {
          strong_against: [ "The Rebel", "The Ruler" ],
          weak_against: [ "The Sage", "The Magician" ]
        },
        "The Rebel" => {
          strong_against: [ "The Ruler", "The Magician" ],
          weak_against: [ "The Hero", "The Caregiver" ]
        },
        "The Explorer" => {
          strong_against: [ "The Innocent", "The Everyperson" ],
          weak_against: [ "The Creator", "The Sage" ]
        },
        "The Sage" => {
          strong_against: [ "The Hero", "The Explorer" ],
          weak_against: [ "The Magician", "The Jester" ]
        },
        "The Innocent" => {
          strong_against: [ "The Jester", "The Lover" ],
          weak_against: [ "The Explorer", "The Rebel" ]
        },
        "The Creator" => {
          strong_against: [ "The Explorer", "The Caregiver" ],
          weak_against: [ "The Magician", "The Ruler" ]
        },
        "The Ruler" => {
          strong_against: [ "The Everyperson", "The Creator" ],
          weak_against: [ "The Rebel", "The Hero" ]
        },
        "The Caregiver" => {
          strong_against: [ "The Rebel", "The Innocent" ],
          weak_against: [ "The Creator", "The Lover" ]
        },
        "The Everyperson" => {
          strong_against: [ "The Lover", "The Sage" ],
          weak_against: [ "The Ruler", "The Explorer" ]
        },
        "The Jester" => {
          strong_against: [ "The Sage", "The Ruler" ],
          weak_against: [ "The Innocent", "The Lover" ]
        },
        "The Lover" => {
          strong_against: [ "The Caregiver", "The Jester" ],
          weak_against: [ "The Innocent", "The Everyperson" ]
        }
      }

      # 33 Spirit Animals with Stat Modifiers
      SPIRIT_ANIMALS = {
        # Australian Animals
        "Taipan" => { attack: 1.2, defense: 1.0, speed: 1.3 },
        "Saltwater Crocodile" => { attack: 1.2, defense: 1.3, speed: 0.9 },
        "Redback Spider" => { attack: 1.3, defense: 0.8, speed: 1.2 },
        "Box Jellyfish" => { attack: 1.4, defense: 0.7, speed: 1.1 },
        "Blue-Ringed Octopus" => { attack: 1.3, defense: 0.8, speed: 1.3 },
        "Funnel-Web Spider" => { attack: 1.2, defense: 0.9, speed: 1.2 },
        "Kangaroo" => { attack: 1.1, defense: 1.0, speed: 1.3 },
        "Emu" => { attack: 1.0, defense: 1.1, speed: 1.2 },
        "Cassowary" => { attack: 1.3, defense: 1.0, speed: 1.1 },
        "Dingo" => { attack: 1.1, defense: 1.0, speed: 1.2 },
        "Tasmanian Devil" => { attack: 1.2, defense: 1.1, speed: 1.0 },
        "Wombat" => { attack: 1.0, defense: 1.3, speed: 0.8 },
        "Platypus" => { attack: 1.1, defense: 1.1, speed: 1.1 },
        "Koala" => { attack: 0.8, defense: 1.2, speed: 0.7 },
        "Kookaburra" => { attack: 1.1, defense: 0.9, speed: 1.2 },

        # Global Animals
        "Lion" => { attack: 1.3, defense: 1.1, speed: 1.1 },
        "Tiger" => { attack: 1.3, defense: 1.0, speed: 1.2 },
        "Bear" => { attack: 1.2, defense: 1.3, speed: 0.9 },
        "Wolf" => { attack: 1.2, defense: 1.0, speed: 1.2 },
        "Eagle" => { attack: 1.2, defense: 0.9, speed: 1.3 },
        "Shark" => { attack: 1.3, defense: 1.1, speed: 1.2 },
        "Dragon" => { attack: 1.4, defense: 1.2, speed: 1.1 },
        "Phoenix" => { attack: 1.2, defense: 1.0, speed: 1.4 },
        "Panther" => { attack: 1.3, defense: 1.0, speed: 1.3 },
        "Falcon" => { attack: 1.1, defense: 0.8, speed: 1.4 },
        "Cobra" => { attack: 1.3, defense: 0.9, speed: 1.2 },
        "Scorpion" => { attack: 1.2, defense: 1.0, speed: 1.1 },
        "Rhino" => { attack: 1.2, defense: 1.4, speed: 0.8 },
        "Elephant" => { attack: 1.1, defense: 1.4, speed: 0.7 },
        "Cheetah" => { attack: 1.1, defense: 0.8, speed: 1.5 },
        "Gorilla" => { attack: 1.3, defense: 1.2, speed: 0.9 },
        "Octopus" => { attack: 1.0, defense: 0.9, speed: 1.3 },

        # Special/Meme
        "Loftbubu" => { attack: 1.2, defense: 1.1, speed: 1.3 }
      }

      # Archetype Abilities & Special Moves
      ARCHETYPE_ABILITIES = {
        "The Magician" => {
          special_moves: [
            { name: "Arcane Blast", description: "Unleash raw magical energy", damage_bonus: 1.1 },
            { name: "Mana Shield", description: "Absorb incoming damage with magic", defense_bonus: 1.2 },
            { name: "Spell Steal", description: "Copy opponent's power", special: true }
          ],
          passive: "Spell Mastery: +10% damage against weak types",
          description: "Masters of arcane arts who bend reality to their will",
          playstyle: "High burst damage, vulnerable to physical attacks"
        },
        "The Hero" => {
          special_moves: [
            { name: "Heroic Strike", description: "A powerful righteous blow", damage_bonus: 1.15 },
            { name: "Shield Bash", description: "Stun with defensive prowess", defense_bonus: 1.1 },
            { name: "Rally", description: "Inspire courage in dire moments", special: true }
          ],
          passive: "Courage: +5% defense when below 50% HP",
          description: "Brave warriors who fight for justice and protect the weak",
          playstyle: "Balanced offense and defense, strong finisher"
        },
        "The Rebel" => {
          special_moves: [
            { name: "Chaos Strike", description: "Unpredictable devastating attack", damage_bonus: 1.2 },
            { name: "Rule Breaker", description: "Ignore type disadvantages", special: true },
            { name: "Anarchy", description: "Random powerful effect", special: true }
          ],
          passive: "Unpredictable: Damage variance increased to ±25%",
          description: "Chaotic forces that break conventions and defy authority",
          playstyle: "High risk, high reward with unpredictable outcomes"
        },
        "The Explorer" => {
          special_moves: [
            { name: "Swift Strike", description: "Lightning-fast attack", speed_bonus: 1.2 },
            { name: "Evasion", description: "Dodge incoming attacks", defense_bonus: 1.15 },
            { name: "Discovery", description: "Find hidden advantages", special: true }
          ],
          passive: "Pathfinder: +15% speed in all battles",
          description: "Adventurers who seek the unknown and adapt quickly",
          playstyle: "Speed-focused, strike first and often"
        },
        "The Sage" => {
          special_moves: [
            { name: "Wisdom Strike", description: "Attack with ancient knowledge", damage_bonus: 1.1 },
            { name: "Meditation", description: "Restore focus and energy", special: true },
            { name: "Enlightenment", description: "See through opponent's strategy", special: true }
          ],
          passive: "Ancient Knowledge: Immune to critical hits",
          description: "Wise scholars who understand the deeper truths",
          playstyle: "Defensive and strategic, counters aggression"
        },
        "The Innocent" => {
          special_moves: [
            { name: "Pure Heart", description: "Attack with untainted spirit", damage_bonus: 1.05 },
            { name: "Hope", description: "Never give up, even at 1 HP", special: true },
            { name: "Inspire", description: "Boost all stats temporarily", special: true }
          ],
          passive: "Purity: Cannot be affected by status effects",
          description: "Pure souls who believe in the goodness of all",
          playstyle: "Supportive and resilient, hard to defeat"
        },
        "The Creator" => {
          special_moves: [
            { name: "Forge", description: "Create powerful constructs", damage_bonus: 1.1 },
            { name: "Innovate", description: "Adapt and overcome", defense_bonus: 1.1 },
            { name: "Masterpiece", description: "Ultimate creation", damage_bonus: 1.3 }
          ],
          passive: "Innovation: Abilities get stronger each turn",
          description: "Inventors and artists who shape reality through creation",
          playstyle: "Scales up over time, strong in long battles"
        },
        "The Ruler" => {
          special_moves: [
            { name: "Command", description: "Dominate the battlefield", damage_bonus: 1.15 },
            { name: "Royal Decree", description: "Force opponent to obey", special: true },
            { name: "Conquer", description: "Overwhelming show of power", damage_bonus: 1.2 }
          ],
          passive: "Authority: +10% all stats when HP is above 75%",
          description: "Leaders who command respect and control the flow of battle",
          playstyle: "Dominant when ahead, struggles from behind"
        },
        "The Caregiver" => {
          special_moves: [
            { name: "Protect", description: "Shield from harm", defense_bonus: 1.25 },
            { name: "Heal", description: "Restore vitality", special: true },
            { name: "Sacrifice", description: "Take damage to empower", special: true }
          ],
          passive: "Nurture: Regenerate 2 HP per turn",
          description: "Compassionate souls who protect and nurture others",
          playstyle: "Defensive tank, outlasts opponents"
        },
        "The Everyperson" => {
          special_moves: [
            { name: "Common Sense", description: "Practical and effective", damage_bonus: 1.0 },
            { name: "Adaptability", description: "Adjust to any situation", special: true },
            { name: "Persistence", description: "Never flashy, always reliable", damage_bonus: 1.1 }
          ],
          passive: "Relatable: No weaknesses, no strengths (all neutral matchups become slight advantage)",
          description: "Ordinary people who succeed through determination",
          playstyle: "Balanced and consistent, no surprises"
        },
        "The Jester" => {
          special_moves: [
            { name: "Trick Shot", description: "Confusing comedic attack", damage_bonus: 1.1 },
            { name: "Mockery", description: "Taunt and distract", special: true },
            { name: "Wild Card", description: "Completely random effect", special: true }
          ],
          passive: "Chaos: 10% chance to dodge any attack",
          description: "Tricksters who use humor and chaos as weapons",
          playstyle: "Unpredictable and fun, keeps opponents guessing"
        },
        "The Lover" => {
          special_moves: [
            { name: "Passion Strike", description: "Attack with intense emotion", damage_bonus: 1.2 },
            { name: "Charm", description: "Reduce opponent's effectiveness", special: true },
            { name: "Devotion", description: "Fight with everything you have", damage_bonus: 1.25 }
          ],
          passive: "Intensity: Deal more damage as HP decreases",
          description: "Passionate souls who fight with heart and emotion",
          playstyle: "Glass cannon, devastating when low HP"
        }
      }

      # Battle Mechanics Constants
      BATTLE_MECHANICS = {
        max_hp: 100,
        max_turns: 20,
        base_damage_multiplier: 10,
        random_variance: { min: 0.85, max: 1.15 },
        type_multipliers: {
          strong: 1.5,
          neutral: 1.0,
          weak: 0.75
        },
        minimum_damage: 5
      }
    end
  end
end
