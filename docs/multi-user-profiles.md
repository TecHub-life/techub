# Multi-User Profile System

## Overview

The TecHub profile system is designed to handle **any GitHub user**, not just a single hardcoded user. All profile data is stored in the database and can be accessed dynamically.

## Database Storage

### Profiles Table

All profile data is stored in the `profiles` table:

```ruby
create_table "profiles" do |t|
  t.string "github_login", null: false     # Unique GitHub username
  t.string "name"                          # Display name
  t.string "avatar_url"                    # Local or GitHub avatar URL
  t.text "summary"                         # AI-generated summary
  t.json "data", default: {}, null: false  # Complete profile payload
  t.datetime "last_synced_at"              # Last refresh timestamp
  t.datetime "created_at"
  t.datetime "updated_at"
  
  t.index ["github_login"], unique: true
end
```

### Data Stored in JSON Column

The `data` JSON column contains the complete profile payload:

```json
{
  "profile": {
    "id": 123,
    "login": "username",
    "name": "Full Name",
    "avatar_url": "https://github.com/username.png",
    "bio": "User bio",
    "company": "Company Name",
    "location": "City, Country",
    "blog": "https://example.com",
    "followers": 1140,
    "following": 524,
    "public_repos": 356,
    "public_gists": 10,
    "created_at": "2014-01-01T00:00:00Z"
  },
  "top_repositories": [
    {
      "name": "repo-name",
      "description": "Repo description",
      "html_url": "https://github.com/username/repo-name",
      "stargazers_count": 100,
      "forks_count": 20,
      "language": "Ruby",
      "topics": ["rails", "ruby"]
    }
  ],
  "pinned_repositories": [...],
  "active_repositories": [...],
  "languages": {
    "Ruby": 50,
    "JavaScript": 30,
    "Python": 20
  },
  "profile_readme": "Full README content...",
  "recent_activity": {
    "total_events": 100,
    "event_breakdown": {...},
    "recent_repos": [...],
    "last_active": "2025-10-04T00:00:00Z"
  }
}
```

## Accessing Any User's Profile

### URL Structure

Access any GitHub user's profile via:

```
https://techub.dev/username
```

Examples:
- `https://techub.dev/loftwah`
- `https://techub.dev/dhh`
- `https://techub.dev/matz`
- `https://techub.dev/torvalds`

### How It Works

1. User visits `/:username`
2. System checks if profile exists in database
3. If exists and recent (< 1 hour old): Show cached data
4. If exists but stale (> 1 hour old): Refresh from GitHub
5. If doesn't exist: Fetch from GitHub and create profile

### Smart Caching

Profiles are automatically cached for 1 hour to:
- Reduce GitHub API calls
- Improve response times
- Stay within rate limits

To force a refresh:
```bash
bin/rails 'profiles:refresh[username]'
```

## Managing Profiles

### View All Profiles

```bash
sqlite3 storage/development.sqlite3 "SELECT github_login, name, last_synced_at FROM profiles;"
```

### Add a New Profile

Visit the user's profile URL or run:
```bash
bin/rails 'profiles:refresh[username]'
```

### Refresh All Profiles

```bash
bin/rails profiles:refresh_all
```

### Delete a Profile

```bash
bin/rails runner "Profile.find_by(github_login: 'username')&.destroy"
```

## Code Examples

### Fetching a Profile in Code

```ruby
# Find existing profile
profile = Profile.find_by(github_login: "username")

# Find or sync from GitHub
result = Profiles::SyncFromGithub.call(login: "username")
if result.success?
  profile = result.value
end

# Access profile data
profile.summary                    # => "AI-generated summary"
profile.data["profile"]["followers"]  # => 1140
profile.data["pinned_repositories"]   # => [...]
```

### Adding a Profile Link in Views

```erb
<%= link_to "@#{username}", profile_path(username: username) %>
```

### Checking if Profile is Stale

```ruby
profile.last_synced_at && profile.last_synced_at > 1.hour.ago
```

## API Rate Limits

Each profile sync makes several GitHub API calls:
- User data (REST API)
- Repositories (REST API)
- User events (REST API)
- Pinned repos (GraphQL API)
- Active repo details (REST API × 5)

**Total: ~8-10 API calls per sync**

GitHub rate limits:
- Unauthenticated: 60 requests/hour
- Authenticated (App): 5,000 requests/hour
- Authenticated (User OAuth): 5,000 requests/hour

With caching, you can sync ~500 profiles per hour safely.

## Future Enhancements

Consider:
1. Background job for automatic profile refreshes
2. Profile search/directory page
3. Compare profiles feature
4. Trending profiles leaderboard
5. Profile analytics over time
6. Webhook-based real-time updates

## Current Home Page

The home page (`/`) is currently hardcoded to show "loftwah". To make it dynamic:

### Option 1: Show Current User's Profile
```ruby
# In PagesController#home
def home
  if current_user
    redirect_to profile_path(username: current_user.login)
  else
    # Show landing page or featured profile
  end
end
```

### Option 2: Show Featured Profile
```ruby
def home
  featured_username = ENV.fetch("FEATURED_PROFILE", "loftwah")
  @profile = Profile.find_by(github_login: featured_username)
  # ... rest of logic
end
```

### Option 3: Show Directory/Leaderboard
```ruby
def home
  @featured_profiles = Profile.order(created_at: :desc).limit(10)
  render "pages/directory"
end
```

## Summary

✅ All data is stored in the database  
✅ System supports unlimited users  
✅ Profile URLs work for any GitHub user  
✅ Smart caching reduces API calls  
✅ Easy to switch between users  
✅ Future-proof architecture  

The system is **ready for multi-user from day one**!

