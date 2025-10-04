# Quick Start: Multi-User Profiles

## Yes, Everything is Stored in the Database!

All profile data is permanently stored in the `profiles` table including:

- Profile info (followers, following, repos, etc.)
- Pinned repositories (up to 6)
- Active public repositories (up to 5)
- Top repositories by stars (up to 5)
- Languages breakdown
- Full profile README (up to 5000 chars displayed)
- Recent activity stats

## View Any GitHub User's Profile

The system works for **any GitHub user**, not just "loftwah"!

### Try These URLs:

```bash
# Visit in your browser:
http://localhost:3000/loftwah      # Your profile
http://localhost:3000/dhh          # DHH's profile
http://localhost:3000/matz         # Matz's profile
http://localhost:3000/torvalds     # Linus Torvalds' profile
```

The system will:

1. Check if the profile exists in the database
2. If not, fetch it from GitHub and store it
3. If it exists but is stale (> 1 hour old), refresh it
4. Display the profile data

## Command Line Management

### Refresh a Specific Profile

```bash
bin/rails 'profiles:refresh[username]'
```

### Refresh All Profiles

```bash
bin/rails profiles:refresh_all
```

### View All Stored Profiles

```bash
sqlite3 storage/development.sqlite3 "SELECT github_login, name, last_synced_at FROM profiles;"
```

## Database Schema

```sql
CREATE TABLE profiles (
  github_login VARCHAR UNIQUE,  -- GitHub username
  name VARCHAR,                  -- Display name
  avatar_url VARCHAR,            -- Avatar image path
  summary TEXT,                  -- AI-generated summary
  data JSON,                     -- Complete profile data
  last_synced_at DATETIME,       -- Last refresh time
  created_at DATETIME,
  updated_at DATETIME
);
```

## The Home Page (/) Issue

Currently, the home page (`/`) is hardcoded to "loftwah". You have several options:

### Option 1: Keep it as your demo profile

Leave it as is - it's a good landing page showing what the system can do.

### Option 2: Redirect to current user

```ruby
# In PagesController#home
def home
  if current_user
    redirect_to profile_path(username: current_user.login)
  else
    # Show landing page
  end
end
```

### Option 3: Make it configurable

```ruby
# Use environment variable
featured_profile = ENV.fetch("FEATURED_PROFILE", "loftwah")
@profile = Profile.find_by(github_login: featured_profile)
```

## Architecture: Future-Proof ✅

The system is designed for scale from day one:

- ✅ Profiles table supports unlimited users
- ✅ URL structure: `/:username` works for anyone
- ✅ Smart caching (1 hour) reduces API calls
- ✅ All data stored in database for processing
- ✅ Easy to add features like:
  - User directory / search
  - Profile comparisons
  - Leaderboards
  - Analytics over time
  - Trending profiles

## Summary

You're all set! The system can handle any GitHub user right now. When you're ready to scale:

1. Data is already in the database ✅
2. Multi-user URLs work ✅
3. Smart caching is active ✅
4. Easy to query and process data ✅

Just change the home page when you're ready, and you're good to go!
