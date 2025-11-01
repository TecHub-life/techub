# TecHub Battle API Documentation

## Base URL

```
Production: https://techub.life/api/v1
Development: http://localhost:3000/api/v1
```

## Authentication

All endpoints are public (no auth required for read operations).

---

## Endpoints

### 1. Get Profile Card with Stats

Get a single profile's card including battle stats.

```http
GET /api/v1/profiles/:username/card
```

**Example:**

```bash
curl https://techub.life/api/v1/profiles/loftwah/card
```

**Response:**

```json
{
  "profile": {
    "id": 1,
    "login": "loftwah",
    "name": "Dean Lofts",
    "avatar_url": "https://avatars.githubusercontent.com/u/19922556",
    "bio": "DevOps Engineer",
    "location": "Perth, Australia",
    "followers": 150,
    "updated_at": "2025-10-30T10:00:00Z"
  },
  "card": {
    "title": "The DevOps Wizard",
    "vibe": "Chaotic Good Automator",
    "archetype": "The Magician",
    "spirit_animal": "Loftbubu",
    "attack": 85,
    "defense": 72,
    "speed": 88,
    "tags": ["devops", "kubernetes", "automation"],
    "special_moves": ["Deploy to Production", "Infrastructure as Code"],
    "playing_card": "Ace of ♠",
    "avatar_choice": "ai_generated"
  }
}
```

---

### 2. List Battle-Ready Profiles

Get all profiles that have cards (can battle).

```http
GET /api/v1/profiles/battle-ready?limit=100
```

**Query Parameters:**

- `limit` (optional): Max profiles to return (default: 100)

**Example:**

```bash
curl https://techub.life/api/v1/profiles/battle-ready?limit=50
```

**Response:**

```json
{
  "profiles": [
    {
      "id": 1,
      "login": "loftwah",
      "name": "Dean Lofts",
      "avatar_url": "https://avatars.githubusercontent.com/u/19922556",
      "card": {
        "archetype": "The Magician",
        "spirit_animal": "Loftbubu",
        "attack": 85,
        "defense": 72,
        "speed": 88
      }
    },
    {
      "id": 2,
      "login": "GameDevJared89",
      "name": "Jared Hooker",
      "avatar_url": "https://avatars.githubusercontent.com/u/123456",
      "card": {
        "archetype": "The Hero",
        "spirit_animal": "Taipan",
        "attack": 90,
        "defense": 65,
        "speed": 92
      }
    }
  ]
}
```

---

### 3. List Recent Battles

Get a list of completed battles.

```http
GET /api/v1/battles?limit=50
```

**Query Parameters:**

- `limit` (optional): Max battles to return (default: 50)

**Example:**

```bash
curl https://techub.life/api/v1/battles?limit=20
```

**Response:**

```json
[
  {
    "id": 123,
    "challenger": {
      "id": 1,
      "login": "loftwah",
      "name": "Dean Lofts",
      "avatar_url": "https://avatars.githubusercontent.com/u/19922556"
    },
    "opponent": {
      "id": 2,
      "login": "GameDevJared89",
      "name": "Jared Hooker",
      "avatar_url": "https://avatars.githubusercontent.com/u/123456"
    },
    "winner": {
      "id": 1,
      "login": "loftwah",
      "name": "Dean Lofts",
      "avatar_url": "https://avatars.githubusercontent.com/u/19922556"
    },
    "challenger_hp": 45,
    "opponent_hp": 0,
    "status": "completed",
    "created_at": "2025-10-30T10:30:00Z",
    "turns": 8
  }
]
```

---

### 4. Get Battle Details

Get full battle details including the complete battle log.

```http
GET /api/v1/battles/:id
```

**Example:**

```bash
curl https://techub.life/api/v1/battles/123
```

**Response:**

```json
{
  "id": 123,
  "challenger": {
    "id": 1,
    "login": "loftwah",
    "name": "Dean Lofts",
    "avatar_url": "https://avatars.githubusercontent.com/u/19922556",
    "card": {
      "archetype": "The Magician",
      "spirit_animal": "Loftbubu",
      "attack": 85,
      "defense": 72,
      "speed": 88,
      "vibe": "Chaotic Good Automator"
    }
  },
  "opponent": {
    "id": 2,
    "login": "GameDevJared89",
    "name": "Jared Hooker",
    "avatar_url": "https://avatars.githubusercontent.com/u/123456",
    "card": {
      "archetype": "The Hero",
      "spirit_animal": "Taipan",
      "attack": 90,
      "defense": 65,
      "speed": 92,
      "vibe": "Righteous Code Warrior"
    }
  },
  "winner": {
    "id": 1,
    "login": "loftwah",
    "name": "Dean Lofts",
    "avatar_url": "https://avatars.githubusercontent.com/u/19922556"
  },
  "challenger_hp": 45,
  "opponent_hp": 0,
  "status": "completed",
  "battle_log": [
    {
      "type": "battle_start",
      "message": "Battle begins between loftwah and GameDevJared89!",
      "timestamp": 1730289000
    },
    {
      "type": "type_advantage",
      "attacker": "loftwah",
      "defender": "GameDevJared89",
      "attacker_archetype": "The Magician",
      "defender_archetype": "The Hero",
      "multiplier": 1.5,
      "message": "The Magician has type advantage over The Hero!",
      "timestamp": 1730289001
    },
    {
      "type": "speed_check",
      "message": "GameDevJared89 (speed: 92) goes first!",
      "timestamp": 1730289002
    },
    {
      "type": "attack",
      "turn": 1,
      "attacker": "GameDevJared89",
      "defender": "loftwah",
      "damage": 12.4,
      "defender_hp": 87.6,
      "special_move": "Commit and Push",
      "timestamp": 1730289003
    },
    {
      "type": "attack",
      "turn": 2,
      "attacker": "loftwah",
      "defender": "GameDevJared89",
      "damage": 18.7,
      "defender_hp": 81.3,
      "special_move": "Deploy to Production",
      "timestamp": 1730289004
    },
    {
      "type": "knockout",
      "message": "GameDevJared89 has been knocked out!",
      "timestamp": 1730289020
    },
    {
      "type": "battle_end",
      "winner": "loftwah",
      "message": "loftwah wins the battle!",
      "timestamp": 1730289021
    }
  ],
  "metadata": {},
  "created_at": "2025-10-30T10:30:00Z",
  "updated_at": "2025-10-30T10:30:21Z"
}
```

---

### 5. Create New Battle

Simulate a battle between two profiles.

```http
POST /api/v1/battles
Content-Type: application/json
```

**Request Body:**

```json
{
  "challenger_id": 1,
  "opponent_id": 2
}
```

**Example:**

```bash
curl -X POST https://techub.life/api/v1/battles \
  -H "Content-Type: application/json" \
  -d '{"challenger_id": 1, "opponent_id": 2}'
```

**Response:** Same as GET /api/v1/battles/:id (returns the complete battle details)

**Error Response:**

```json
{
  "error": "Profile has no card"
}
```

---

## Battle Log Event Types

### battle_start

```json
{
  "type": "battle_start",
  "message": "Battle begins between loftwah and GameDevJared89!",
  "timestamp": 1730289000
}
```

### type_advantage

```json
{
  "type": "type_advantage",
  "attacker": "loftwah",
  "defender": "GameDevJared89",
  "attacker_archetype": "The Magician",
  "defender_archetype": "The Hero",
  "multiplier": 1.5,
  "message": "The Magician has type advantage over The Hero!",
  "timestamp": 1730289001
}
```

### speed_check

```json
{
  "type": "speed_check",
  "message": "GameDevJared89 (speed: 92) goes first!",
  "timestamp": 1730289002
}
```

### attack

```json
{
  "type": "attack",
  "turn": 1,
  "attacker": "GameDevJared89",
  "defender": "loftwah",
  "damage": 12.4,
  "defender_hp": 87.6,
  "special_move": "Commit and Push",
  "timestamp": 1730289003
}
```

### knockout

```json
{
  "type": "knockout",
  "message": "GameDevJared89 has been knocked out!",
  "timestamp": 1730289020
}
```

### battle_end

```json
{
  "type": "battle_end",
  "winner": "loftwah",
  "message": "loftwah wins the battle!",
  "timestamp": 1730289021
}
```

---

## Battle Mechanics

### Type Advantages

Each archetype has strengths and weaknesses:

- **Strong matchup**: 1.5x damage multiplier
- **Weak matchup**: 0.75x damage multiplier
- **Neutral**: 1.0x damage multiplier

See `docs/battle-system.md` for complete type chart.

### Spirit Animal Modifiers

Each spirit animal provides stat bonuses:

- **Taipan**: Speed 1.3x, Attack 1.2x
- **Loftbubu**: Speed 1.3x, Attack 1.2x, Defense 1.1x
- **Saltwater Crocodile**: Defense 1.3x, Attack 1.2x

See `app/services/battles/simulate_service.rb` for complete list.

### Damage Calculation

```
base_damage = (attacker_attack / defender_defense) * 10
random_factor = 0.85 to 1.15 (±15% variance)
type_multiplier = 0.75x, 1.0x, or 1.5x
final_damage = base_damage * random_factor * type_multiplier
minimum_damage = 5
```

### Turn Order

- Determined by Speed stat (with spirit animal modifiers)
- Faster card attacks first each turn
- Battle continues until one card reaches 0 HP or 20 turns elapse

---

## CORS

CORS is enabled for all `/api/v1/*` endpoints.

**Development**: All origins allowed **Production**: Restrict to your React app's domain in
`config/initializers/cors.rb`

---

## Rate Limiting

Currently no rate limiting. May be added in future.

---

## Error Responses

### 404 Not Found

```json
{
  "error": "not_found"
}
```

### 422 Unprocessable Entity

```json
{
  "error": "Profile has no card"
}
```

---

## Example React Integration

```javascript
// Fetch battle-ready profiles
const response = await fetch('https://techub.life/api/v1/profiles/battle-ready')
const { profiles } = await response.json()

// Create a battle
const battleResponse = await fetch('https://techub.life/api/v1/battles', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    challenger_id: profiles[0].id,
    opponent_id: profiles[1].id,
  }),
})
const battle = await battleResponse.json()

// Animate the battle log
battle.battle_log.forEach((event, index) => {
  setTimeout(() => {
    console.log(event.message)
    // Update UI based on event type
  }, index * 1000)
})
```

---

## Next Steps

1. **Install gem**: `bundle install` (adds rack-cors)
2. **Restart server**: Required for CORS config to load
3. **Test endpoints**: Use curl or Postman
4. **Build React app**: Consume these endpoints

---

## Support

For issues or questions, see:

- Full battle system docs: `docs/battle-system.md`
- Quick start guide: `docs/battle-system-quickstart.md`
