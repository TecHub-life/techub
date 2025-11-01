# Battle System Documentation

## Overview

The TecHub Battle System allows GitHub developer cards to battle each other using their stats
(ATK/DEF/SPD), archetypes, and spirit animals. The system is inspired by Pokémon's type advantage
mechanics and is designed to be easily expandable for future features like animations, sound
effects, and real-time battles.

## Architecture

### Models

#### Battle (`app/models/battle.rb`)

Stores battle records with the following key fields:

- `challenger_profile_id` - The initiating profile
- `opponent_profile_id` - The defending profile
- `winner_profile_id` - The victorious profile (null until completed)
- `challenger_hp` - Final HP of challenger (0-100)
- `opponent_hp` - Final HP of opponent (0-100)
- `status` - Battle state: `pending`, `in_progress`, `completed`
- `battle_log` - JSON array of battle events
- `metadata` - JSON object for extensibility

**Associations:**

- `belongs_to :challenger_profile`
- `belongs_to :opponent_profile`
- `belongs_to :winner_profile` (optional)

**Scopes:**

- `Battle.completed` - All finished battles
- `Battle.pending` - Queued battles
- `Battle.recent` - Ordered by creation date
- `Battle.for_profile(id)` - All battles involving a profile

#### Profile Extensions

Added battle-related associations and methods:

- `has_many :battles_as_challenger`
- `has_many :battles_as_opponent`
- `has_many :battles_won`
- `all_battles` - Returns all battles (as challenger or opponent)
- `battle_record` - Returns wins, losses, total, and win_rate
- `battle_ready?` - Checks if profile has a card

### Services

#### Battles::SimulateService (`app/services/battles/simulate_service.rb`)

Core battle simulation logic following the ServiceResult pattern.

**Usage:**

```ruby
result = Battles::SimulateService.call(
  challenger_id: 1,
  opponent_id: 2
)

if result.success?
  battle = result.value
  puts "Winner: #{battle.winner.login}"
else
  puts "Error: #{result.error.message}"
end
```

**Battle Flow:**

1. Validate profiles exist and have cards
2. Create battle record with `in_progress` status
3. Calculate effective stats with spirit animal modifiers
4. Determine type advantages
5. Speed check determines turn order
6. Turn-based combat loop (max 20 turns)
7. Update battle with winner and final HP
8. Return completed battle

### Controllers

#### BattlesController (`app/controllers/battles_controller.rb`)

RESTful controller with authentication for battle creation.

**Actions:**

- `index` - List recent battles (paginated)
- `show` - Display battle details and log
- `new` - Battle setup form
- `create` - Initiate battle simulation

**Authentication:**

- `new` and `create` require user login
- Public viewing of battles (index/show)

### Views

#### Battles Index (`app/views/battles/index.html.erb`)

- Battle statistics dashboard
- Recent battles list with participant info
- Winner badges and HP displays
- Responsive grid layout

#### Battle Show (`app/views/battles/show.html.erb`)

- Detailed battle participants with stats
- Complete battle log with turn-by-turn breakdown
- Type advantage indicators
- Winner/loser highlighting
- Visual HP bars and stat displays

#### Battle New (`app/views/battles/new.html.erb`)

- Dropdown selectors for challenger and opponent
- Type advantage reference chart
- Battle system explanation
- Form validation

## Battle Mechanics

### Type Advantages (Archetype System)

Inspired by Pokémon, each archetype has strengths and weaknesses:

**Damage Multipliers:**

- Strong against: **1.5x damage** (50% bonus)
- Weak against: **0.75x damage** (25% reduction)
- Neutral: **1.0x damage**

**Type Chart:**

```
The Hero → Strong vs: Innocent, Everyman | Weak vs: Outlaw, Magician
The Outlaw → Strong vs: Hero, Ruler | Weak vs: Sage, Caregiver
The Explorer → Strong vs: Innocent, Lover | Weak vs: Hero, Ruler
The Creator → Strong vs: Everyman, Jester | Weak vs: Outlaw, Explorer
The Ruler → Strong vs: Everyman, Caregiver | Weak vs: Outlaw, Magician
The Magician → Strong vs: Hero, Ruler | Weak vs: Sage, Creator
The Lover → Strong vs: Jester, Caregiver | Weak vs: Explorer, Sage
The Caregiver → Strong vs: Innocent, Lover | Weak vs: Outlaw, Ruler
The Jester → Strong vs: Sage, Ruler | Weak vs: Creator, Hero
The Sage → Strong vs: Outlaw, Magician | Weak vs: Jester, Innocent
The Innocent → Strong vs: Sage, Jester | Weak vs: Hero, Explorer
The Everyman → Strong vs: Creator, Explorer | Weak vs: Hero, Ruler
```

### Spirit Animal Modifiers

Each spirit animal provides stat multipliers:

**Examples:**

- **Taipan**: Speed 1.3x, Attack 1.2x (fast striker)
- **Saltwater Crocodile**: Defense 1.3x, Attack 1.2x (tank)
- **Loftbubu**: Speed 1.3x, Attack 1.2x, Defense 1.1x (balanced powerhouse)
- **Koala**: Defense 1.3x, Speed 0.9x (defensive wall)
- **Sugar Glider**: Speed 1.3x, Defense 0.9x (glass cannon)

See `SPIRIT_ANIMAL_MODIFIERS` in `Battles::SimulateService` for complete list.

### Damage Calculation

```ruby
base_damage = (attacker_attack / defender_defense) * 10
random_factor = 0.85 + (rand * 0.3)  # 0.85 to 1.15
final_damage = base_damage * random_factor * type_advantage
final_damage = [final_damage, 5].max  # Minimum 5 damage
```

**Factors:**

1. **Attack vs Defense ratio** - Core damage calculation
2. **Random variance** - ±15% for unpredictability
3. **Type advantage** - 0.75x, 1.0x, or 1.5x multiplier
4. **Minimum damage** - Always deal at least 5 damage

### Turn Order

- Determined by **Speed stat** (with spirit animal modifiers)
- Faster card attacks first each turn
- Attacker and defender swap after each attack
- Battle continues until one card reaches 0 HP or 20 turns elapse

### Battle Log Events

The `battle_log` JSON array tracks all battle events:

**Event Types:**

- `battle_start` - Battle initialization
- `type_advantage` - Type advantage detected
- `speed_check` - Turn order determination
- `attack` - Damage dealt with turn number
- `knockout` - Card defeated
- `battle_end` - Victory declaration

**Example Log Entry:**

```json
{
  "type": "attack",
  "turn": 3,
  "attacker": "loftwah",
  "defender": "GameDevJared89",
  "damage": 12.4,
  "defender_hp": 67.6,
  "special_move": "Deploy to Production",
  "timestamp": 1730318400
}
```

## Routes

```ruby
GET    /battles          # List all battles
GET    /battles/:id      # Show battle details
GET    /battles/new      # Battle setup form (auth required)
POST   /battles          # Create and simulate battle (auth required)
```

## Database Schema

```ruby
create_table :battles do |t|
  t.integer :challenger_profile_id, null: false
  t.integer :opponent_profile_id, null: false
  t.integer :winner_profile_id
  t.integer :challenger_hp, default: 100
  t.integer :opponent_hp, default: 100
  t.string :status, default: "pending", null: false
  t.json :battle_log, default: []
  t.json :metadata, default: {}
  t.timestamps
end

add_index :battles, :challenger_profile_id
add_index :battles, :opponent_profile_id
add_index :battles, :winner_profile_id
add_index :battles, :status
add_index :battles, :created_at
```

## Future Enhancements

### Phase 2: Visual Enhancements

- [ ] Stimulus controller for animated battles
- [ ] CSS animations for attacks and HP changes
- [ ] Sound effects for hits, knockouts, victories
- [ ] Particle effects for special moves
- [ ] Animated type advantage indicators

### Phase 3: Advanced Features

- [ ] Real-time battles with ActionCable
- [ ] Tournaments and brackets
- [ ] Ranked matchmaking system
- [ ] Battle replays
- [ ] Spectator mode
- [ ] Battle statistics and leaderboards

### Phase 4: Gameplay Depth

- [ ] Status effects (burn, freeze, paralysis)
- [ ] Critical hits
- [ ] Dodge/evasion mechanics
- [ ] Special move system (unique abilities per card)
- [ ] Item system (boosts, healing)
- [ ] Team battles (2v2, 3v3)

### Phase 5: Social Features

- [ ] Battle challenges (send to specific users)
- [ ] Battle history on profile pages
- [ ] Share battle results on social media
- [ ] Battle commentary system
- [ ] Achievements and badges

## Testing

### Manual Testing

1. **Run migration:**

   ```bash
   rails db:migrate
   ```

2. **Create test battle in console:**

   ```ruby
   # Ensure profiles have cards
   challenger = Profile.joins(:profile_card).first
   opponent = Profile.joins(:profile_card).second

   # Simulate battle
   result = Battles::SimulateService.call(
     challenger_id: challenger.id,
     opponent_id: opponent.id
   )

   # View results
   battle = result.value
   puts "Winner: #{battle.winner.login}"
   puts "Final HP: #{battle.challenger_hp} vs #{battle.opponent_hp}"
   pp battle.battle_log
   ```

3. **Test via web interface:**
   - Visit `/battles/new`
   - Select two profiles
   - Click "Start Battle!"
   - View battle log at `/battles/:id`

### Automated Testing (TODO)

```ruby
# test/services/battles/simulate_service_test.rb
class Battles::SimulateServiceTest < ActiveSupport::TestCase
  test "battle completes successfully" do
    # Test implementation
  end

  test "type advantage applies correctly" do
    # Test implementation
  end

  test "spirit animal modifiers work" do
    # Test implementation
  end
end
```

## Performance Considerations

- **Battle simulation is synchronous** - Runs in the request cycle
- Average simulation time: ~50-100ms
- For high traffic, consider:
  - Background job processing (Solid Queue)
  - Caching battle results
  - Rate limiting battle creation

## Security

- Authentication required to create battles
- Profile ownership not required (anyone can battle any cards)
- Input validation on profile IDs
- SQL injection protection via ActiveRecord
- No user input in battle simulation (deterministic with controlled randomness)

## Extensibility

The system is designed for easy expansion:

1. **Metadata field** - Store future data without migrations
2. **Service pattern** - Easy to add pre/post battle hooks
3. **Event log** - Extensible JSON structure
4. **Modular damage calculation** - Override in subclasses
5. **Type system** - Add new archetypes/animals via constants

## API Integration (Future)

```ruby
# Example API endpoint structure
POST /api/v1/battles
{
  "challenger_id": 1,
  "opponent_id": 2
}

Response:
{
  "battle_id": 123,
  "winner": "loftwah",
  "final_hp": {
    "challenger": 45,
    "opponent": 0
  },
  "turns": 8,
  "url": "/battles/123"
}
```

## Credits

Battle system designed and implemented following Rails 8 best practices:

- Service objects with ServiceResult pattern
- RESTful routing
- Turbo-compatible views
- Tailwind CSS styling
- Dark mode support
- Mobile-responsive design

Inspired by Pokémon's type advantage system and trading card game mechanics.
