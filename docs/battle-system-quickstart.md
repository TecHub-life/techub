# Battle System Quick Start

## Setup

1. **Run the migration:**
   ```bash
   rails db:migrate
   ```

2. **Verify routes:**
   ```bash
   rails routes | grep battles
   ```

   Should show:
   ```
   GET    /battles          battles#index
   GET    /battles/:id      battles#show
   GET    /battles/new      battles#new
   POST   /battles          battles#create
   ```

## Usage

### Web Interface

1. **View all battles:** Visit `/battles`
2. **Start a battle:** Visit `/battles/new` (requires login)
3. **View battle details:** Click any battle from the list

### Console Testing

```ruby
# Find two profiles with cards
challenger = Profile.joins(:profile_card).first
opponent = Profile.joins(:profile_card).second

# Simulate a battle
result = Battles::SimulateService.call(
  challenger_id: challenger.id,
  opponent_id: opponent.id
)

# Check result
if result.success?
  battle = result.value
  puts "Winner: #{battle.winner.login}"
  puts "Challenger HP: #{battle.challenger_hp}"
  puts "Opponent HP: #{battle.opponent_hp}"
  puts "Turns: #{battle.battle_log.count { |e| e['type'] == 'attack' }}"
  
  # View full battle log
  pp battle.battle_log
else
  puts "Error: #{result.error.message}"
end
```

### Check Battle Stats for a Profile

```ruby
profile = Profile.find_by(login: "loftwah")

# Get battle record
record = profile.battle_record
puts "Wins: #{record[:wins]}"
puts "Losses: #{record[:losses]}"
puts "Win Rate: #{record[:win_rate]}%"

# Get all battles
profile.all_battles.each do |battle|
  puts "#{battle.challenger.login} vs #{battle.opponent.login} - Winner: #{battle.winner&.login}"
end
```

## Key Mechanics

### Type Advantages (Quick Reference)

**Strong Matchups (1.5x damage):**
- Hero beats Innocent, Everyman
- Outlaw beats Hero, Ruler
- Magician beats Hero, Ruler
- Sage beats Outlaw, Magician

**Remember:** Type advantage can overcome stat differences!

### Spirit Animal Bonuses

**Top Performers:**
- **Taipan** - Speed 1.3x, Attack 1.2x (fast striker)
- **Loftbubu** - Speed 1.3x, Attack 1.2x, Defense 1.1x (all-rounder)
- **Saltwater Crocodile** - Defense 1.3x, Attack 1.2x (tank)
- **Great White Shark** - Attack 1.3x, Speed 1.1x (damage dealer)

### Damage Formula

```
base_damage = (ATK / DEF) * 10
random_factor = 0.85 to 1.15
type_multiplier = 0.75x, 1.0x, or 1.5x
final_damage = base_damage * random_factor * type_multiplier
minimum_damage = 5
```

## Common Tasks

### Create a Battle via Service

```ruby
Battles::SimulateService.call(
  challenger_id: 1,
  opponent_id: 2
)
```

### Find Recent Battles

```ruby
Battle.recent.limit(10).each do |b|
  puts "#{b.challenger.login} vs #{b.opponent.login}"
end
```

### Get Battle Statistics

```ruby
# Total battles
Battle.completed.count

# Battles in last 24 hours
Battle.where("created_at > ?", 24.hours.ago).count

# Most active battlers
Profile.joins(:battles_as_challenger)
       .group(:id)
       .order("COUNT(*) DESC")
       .limit(10)
```

## Troubleshooting

### "Profile has no card" Error

Profiles need a `profile_card` to battle. Check:
```ruby
profile = Profile.find(id)
profile.battle_ready?  # Should return true
```

If false, the profile needs to go through the pipeline to generate a card.

### "Cannot battle yourself" Error

Challenger and opponent must be different profiles.

### Battle Takes Too Long

Battles are capped at 20 turns. If both cards have very high defense and low attack, battles may hit the turn limit. The winner is determined by remaining HP.

## Files Created

```
db/migrate/TIMESTAMP_create_battles.rb
app/models/battle.rb
app/services/battles/simulate_service.rb
app/controllers/battles_controller.rb
app/views/battles/index.html.erb
app/views/battles/show.html.erb
app/views/battles/new.html.erb
docs/battle-system.md
docs/battle-system-quickstart.md
```

## Next Steps

1. Run migration: `rails db:migrate`
2. Test in console (see examples above)
3. Visit `/battles` in your browser
4. Start a battle at `/battles/new`
5. Read full documentation: `docs/battle-system.md`

## Future Enhancements

- [ ] Add animations with Stimulus
- [ ] Real-time battles with ActionCable
- [ ] Tournament system
- [ ] Battle leaderboards
- [ ] Special moves and abilities
- [ ] Sound effects and visual effects

See `docs/battle-system.md` for detailed roadmap.
