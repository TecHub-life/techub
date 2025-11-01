# 🎮 Battle API is Ready!

## ✅ What's Done

### Rails API Endpoints

1. **GET /api/v1/profiles/:username/card** - Get card with battle stats
2. **GET /api/v1/profiles/battle-ready** - List all profiles with cards
3. **GET /api/v1/battles** - List recent battles
4. **GET /api/v1/battles/:id** - Get battle details with full log
5. **POST /api/v1/battles** - Create new battle

### Files Modified/Created

- ✅ `app/controllers/api/v1/profiles_controller.rb` - Added card endpoints
- ✅ `app/controllers/api/v1/battles_controller.rb` - Battle API (already existed)
- ✅ `app/controllers/api/v1/base_controller.rb` - Base API controller
- ✅ `config/routes.rb` - Added API routes
- ✅ `config/initializers/cors.rb` - CORS configuration
- ✅ `Gemfile` - Added rack-cors gem
- ✅ `docs/battle-api.md` - Complete API documentation

---

## 🚀 Next Steps

### 1. Install Dependencies

```bash
bundle install
```

### 2. Restart Rails Server

```bash
# Stop server (Ctrl+C)
rails s
```

### 3. Test the API

**Get a profile's card:**

```bash
curl http://localhost:3000/api/v1/profiles/loftwah/card
```

**List battle-ready profiles:**

```bash
curl http://localhost:3000/api/v1/profiles/battle-ready
```

**Create a battle:**

```bash
curl -X POST http://localhost:3000/api/v1/battles \
  -H "Content-Type: application/json" \
  -d '{"challenger_id": 1, "opponent_id": 2}'
```

**Get battle details:**

```bash
curl http://localhost:3000/api/v1/battles/1
```

---

## 📋 API Endpoints Summary

| Method | Endpoint                          | Description                 |
| ------ | --------------------------------- | --------------------------- |
| GET    | `/api/v1/profiles/:username/card` | Get profile card with stats |
| GET    | `/api/v1/profiles/battle-ready`   | List profiles with cards    |
| GET    | `/api/v1/battles`                 | List recent battles         |
| GET    | `/api/v1/battles/:id`             | Get battle details + log    |
| POST   | `/api/v1/battles`                 | Create new battle           |

---

## 🎨 React App Next

Your co-founder can now build the React battle viewer that:

1. **Fetches profiles** from `/api/v1/profiles/battle-ready`
2. **Creates battles** via POST `/api/v1/battles`
3. **Animates battle log** from the response
4. **Shows HP bars** draining based on battle events

---

## 📚 Documentation

- **API Docs**: `docs/battle-api.md`
- **Battle System**: `docs/battle-system.md`
- **Quick Start**: `docs/battle-system-quickstart.md`

---

## 🔧 CORS Configuration

Currently set to allow **all origins** for development.

**For production**, edit `config/initializers/cors.rb`:

```ruby
origins 'https://battles.techub.life', 'https://techub.life'
```

---

## 🎮 Example React Usage

```javascript
// 1. Fetch battle-ready profiles
const res = await fetch('https://techub.life/api/v1/profiles/battle-ready')
const { profiles } = await res.json()

// 2. Create a battle
const battleRes = await fetch('https://techub.life/api/v1/battles', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    challenger_id: profiles[0].id,
    opponent_id: profiles[1].id,
  }),
})
const battle = await battleRes.json()

// 3. Animate the battle
battle.battle_log.forEach((event, i) => {
  setTimeout(() => {
    if (event.type === 'attack') {
      updateHP(event.defender, event.defender_hp)
    }
  }, i * 1000)
})
```

---

## ✨ What You Get

### Battle Response Includes:

- ✅ Full profile data (name, avatar, login)
- ✅ Card stats (attack, defense, speed)
- ✅ Archetype and spirit animal
- ✅ Complete battle log (turn-by-turn)
- ✅ Final HP for both fighters
- ✅ Winner information
- ✅ Timestamps for each event

### Battle Log Events:

- `battle_start` - Battle begins
- `type_advantage` - Type matchup detected
- `speed_check` - Turn order determined
- `attack` - Damage dealt
- `knockout` - Fighter defeated
- `battle_end` - Victory declared

---

## 🎯 Ready to Go!

The Rails API is **100% ready** for your React app to consume.

All battle logic stays in Rails (single source of truth). React just needs to fetch data and animate
it beautifully! 🚀
