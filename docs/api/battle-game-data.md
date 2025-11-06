# Battle Game Data API

## Overview

These endpoints provide game data for the Next.js battle application. All battle logic runs
client-side in Next.js to minimize Rails compute costs.

## Base URL

```
Production: https://techub.life/api/v1
Development: http://localhost:3000/api/v1
```

### Frozen profile endpoints for TecHub Battles

To guarantee backwards compatibility, the TecHub Battles client should consume the locked endpoints
under `/api/v1/battles/...`:

```http
GET /api/v1/battles/profiles/:username/card
GET /api/v1/battles/profiles/battle-ready
```

These responses are frozen—any schema changes in the main `/api/v1/profiles/...` routes will only
ship after coordination and doc updates. The frozen endpoints can be cached aggressively because
they will not introduce new keys without a version bump.

---

## Endpoints

### 1. Get All Archetypes & Type Chart

```http
GET /api/v1/game-data/archetypes
```

Returns all 12 archetypes with type advantage chart.

**Response:**

```json
{
  "archetypes": [
    "The Magician",
    "The Hero",
    "The Rebel",
    ...
  ],
  "type_chart": {
    "The Magician": {
      "strong_against": ["The Sage", "The Creator"],
      "weak_against": ["The Rebel", "The Hero"]
    },
    ...
  }
}
```

---

### 2. Get All Spirit Animals

```http
GET /api/v1/game-data/spirit-animals
```

Returns all 33 spirit animals with stat modifiers.

**Response:**

```json
{
  "spirit_animals": {
    "Taipan": {
      "attack": 1.2,
      "defense": 1.0,
      "speed": 1.3
    },
    "Loftbubu": {
      "attack": 1.2,
      "defense": 1.1,
      "speed": 1.3
    },
    ...
  }
}
```

---

### 3. Get All Game Data

```http
GET /api/v1/game-data/all
```

Returns everything in one call (recommended for initial load).

**Response:**

```json
{
  "archetypes": [...],
  "type_chart": {...},
  "spirit_animals": {...},
  "mechanics": {
    "max_hp": 100,
    "max_turns": 20,
    "base_damage_multiplier": 10,
    "random_variance": {
      "min": 0.85,
      "max": 1.15
    },
    "type_multipliers": {
      "strong": 1.5,
      "neutral": 1.0,
      "weak": 0.75
    },
    "minimum_damage": 5
  }
}
```

---

## Battle Mechanics

### Type Advantages

- **Strong matchup**: 1.5x damage multiplier
- **Weak matchup**: 0.75x damage multiplier
- **Neutral**: 1.0x damage multiplier

### Spirit Animal Modifiers

Each spirit animal provides stat bonuses:

- **Taipan**: Speed 1.3x, Attack 1.2x
- **Saltwater Crocodile**: Defense 1.3x, Attack 1.2x, Speed 0.9x
- **Loftbubu**: Speed 1.3x, Attack 1.2x, Defense 1.1x

### Damage Formula

```javascript
// 1. Get base stats with spirit animal modifiers
const attackerAtk = attacker.attack * spiritAnimalModifiers[attacker.spirit_animal].attack
const defenderDef = defender.defense * spiritAnimalModifiers[defender.spirit_animal].defense

// 2. Calculate base damage
const baseDamage = (attackerAtk / defenderDef) * 10

// 3. Apply random variance (±15%)
const randomFactor = Math.random() * (1.15 - 0.85) + 0.85

// 4. Get type multiplier
const typeMultiplier = getTypeMultiplier(attacker.archetype, defender.archetype)

// 5. Final damage
const damage = Math.max(5, baseDamage * randomFactor * typeMultiplier)
```

### Turn Order

- Determined by Speed stat (with spirit animal modifiers)
- Faster card attacks first each turn
- Battle continues until one card reaches 0 HP or 20 turns elapse

---

## Profile Battle Stats

Use the existing profile endpoint to get battle-ready stats:

```http
GET /api/v1/profiles/:username/card
```

**Response includes:**

```json
{
  "profile": {
    "id": 1,
    "login": "loftwah",
    "name": "Dean Lofts",
    "avatar_url": "..."
  },
  "card": {
    "archetype": "The Magician",
    "spirit_animal": "Loftbubu",
    "attack": 85,
    "defense": 72,
    "speed": 88,
    "vibe": "Chaotic Good Automator",
    "special_moves": ["Deploy to Production", "Infrastructure as Code"]
  }
}
```

---

## Next.js Integration

### 1. Fetch Game Data on App Load

```typescript
// lib/game-data.ts
export async function fetchGameData() {
  const res = await fetch('https://techub.life/api/v1/game-data/all')
  return res.json()
}
```

### 2. Fetch Fighter Data

```typescript
// lib/techub-api.ts
export async function fetchFighter(username: string) {
  const res = await fetch(`https://techub.life/api/v1/profiles/${username}/card`)
  return res.json()
}
```

### 3. Run Battle Client-Side

```typescript
// lib/battle-engine.ts
export function simulateBattle(challenger, opponent, gameData) {
  // All battle logic runs in browser
  // No Rails compute needed!
  return battleLog
}
```

---

## Cost Optimization

**Rails (Railway):**

- Only serves JSON data (minimal compute)
- ~100 requests/battle (cheap)

**Next.js (Vercel):**

- Battle simulation runs client-side (FREE)
- Or use Next.js server actions (still cheaper than Rails)
- Unlimited battles on free tier

---

## Example Usage

```bash
# Get all game data
curl https://techub.life/api/v1/game-data/all

# Get fighter stats
curl https://techub.life/api/v1/profiles/loftwah/card
curl https://techub.life/api/v1/profiles/GameDevJared89/card

# Battle happens in Next.js (no Rails API call needed!)
```

---

## CORS

CORS is already configured for `/api/v1/*` endpoints.

For production Next.js app, update `config/initializers/cors.rb`:

```ruby
origins 'https://battles.techub.life', 'https://techub.life'
```
