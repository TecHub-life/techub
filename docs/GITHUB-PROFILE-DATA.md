# GitHub Profile Data Collection & Structure

## Overview

TecHub collects comprehensive GitHub profile data through a structured database schema that stores
all publicly available information about GitHub users. This document outlines exactly what data is
collected, how it's stored, and how it can be accessed.

## Database Schema

### Main Profile Table (`profiles`)

The core profile information is stored in the `profiles` table:

```sql
CREATE TABLE profiles (
  -- Basic Identity
  github_id BIGINT NOT NULL,           -- GitHub's internal user ID
  login VARCHAR NOT NULL,               -- GitHub username (unique)
  name VARCHAR,                          -- Display name
  avatar_url VARCHAR,                    -- Local or GitHub avatar URL

  -- Profile Details
  bio TEXT,                             -- User bio/description
  company VARCHAR,                       -- Current company
  location VARCHAR,                      -- Geographic location
  blog VARCHAR,                         -- Personal website
  email VARCHAR,                        -- Public email
  twitter_username VARCHAR,             -- Twitter handle

  -- Status & Stats
  hireable BOOLEAN DEFAULT false,       -- Open to opportunities
  html_url VARCHAR,                     -- GitHub profile URL
  followers INTEGER DEFAULT 0,          -- Follower count
  following INTEGER DEFAULT 0,          -- Following count
  public_repos INTEGER DEFAULT 0,       -- Public repository count
  public_gists INTEGER DEFAULT 0,       -- Public gist count

  -- Metadata
  summary TEXT,                         -- AI-generated summary
  github_created_at DATETIME,           -- Account creation date
  github_updated_at DATETIME,           -- Last profile update
  last_synced_at DATETIME,              -- Last sync timestamp
  created_at DATETIME,
  updated_at DATETIME
);
```

### Related Tables

#### Profile Repositories (`profile_repositories`)

```sql
CREATE TABLE profile_repositories (
  profile_id INTEGER NOT NULL,
  name VARCHAR NOT NULL,                -- Repository name
  full_name VARCHAR,                    -- owner/repo-name
  description TEXT,                    -- Repository description
  html_url VARCHAR,                     -- GitHub URL
  stargazers_count INTEGER DEFAULT 0,   -- Star count
  forks_count INTEGER DEFAULT 0,        -- Fork count
  language VARCHAR,                     -- Primary language
  repository_type VARCHAR NOT NULL,     -- 'top', 'pinned', 'active'
  github_created_at DATETIME,
  github_updated_at DATETIME
);
```

#### Repository Topics (`repository_topics`)

```sql
CREATE TABLE repository_topics (
  profile_repository_id INTEGER NOT NULL,
  name VARCHAR NOT NULL                 -- Topic/tag name
);
```

#### Profile Organizations (`profile_organizations`)

```sql
CREATE TABLE profile_organizations (
  profile_id INTEGER NOT NULL,
  login VARCHAR NOT NULL,               -- Organization handle
  name VARCHAR,                         -- Organization name
  avatar_url VARCHAR,                   -- Organization avatar
  description TEXT,                     -- Organization description
  html_url VARCHAR                      -- Organization URL
);
```

#### Profile Languages (`profile_languages`)

```sql
CREATE TABLE profile_languages (
  profile_id INTEGER NOT NULL,
  name VARCHAR NOT NULL,                -- Language name
  count INTEGER DEFAULT 0               -- Usage count across repos
);
```

#### Profile Social Accounts (`profile_social_accounts`)

```sql
CREATE TABLE profile_social_accounts (
  profile_id INTEGER NOT NULL,
  provider VARCHAR NOT NULL,            -- 'TWITTER', 'BLUESKY', 'FACEBOOK', 'INSTAGRAM', 'YOUTUBE', 'REDDIT', 'TWITCH', 'MASTODON', 'NPM', etc.
  url VARCHAR,                          -- Social media URL
  display_name VARCHAR                  -- Display name on platform
);
```

#### Profile Activity (`profile_activities`)

```sql
CREATE TABLE profile_activities (
  profile_id INTEGER NOT NULL,
  total_events INTEGER DEFAULT 0,       -- Total events in last 90 days
  event_breakdown JSON DEFAULT {},      -- Event type breakdown
  recent_repos TEXT,                    -- Recent repository activity
  last_active DATETIME                  -- Last activity timestamp
);
```

#### Profile README (`profile_readmes`)

```sql
CREATE TABLE profile_readmes (
  profile_id INTEGER NOT NULL,
  content TEXT                          -- Full README content
);
```

## Data Collection Process

### GitHub API Calls Made Per Profile

For each profile sync, TecHub makes the following API calls:

1. **REST API - User Data** (1 call)
   - Basic profile information
   - Stats (followers, following, repos, gists)

2. **REST API - Repositories** (1 call)
   - All public repositories (paginated, up to 100 per page)
   - Used for language analysis and top repos

3. **REST API - Profile README** (1 call)
   - README from `username/username` repository
   - Downloads and processes images locally

4. **REST API - User Events** (1 call)
   - Recent activity events (last 90 days)
   - Event type breakdown and activity stats

5. **REST API - Organizations** (1 call)
   - Organization memberships
   - Organization details and avatars

6. **REST API - Active Repo Details** (up to 5 calls)
   - Details for each recently active repository
   - Only for public repositories

7. **GraphQL - Pinned Repositories** (1 call)
   - Pinned items via GraphQL query
   - Up to 6 pinned repositories

8. **GraphQL - Social Accounts** (1 call)
   - Connected social media accounts
   - Twitter, Bluesky, LinkedIn, etc.

**Total: 11-16 API calls per profile sync**

### Data Processing

1. **Avatar Download**: Profile avatars are downloaded and stored locally
2. **Image Processing**: README images are downloaded and paths updated
3. **Language Analysis**: Repository languages are counted and ranked
4. **Repository Categorization**: Repos are categorized as 'top', 'pinned', or 'active'
5. **Activity Analysis**: Recent events are analyzed for activity patterns

## Profile Model Methods

### Repository Access

```ruby
profile.top_repositories     # 5 most starred repos
profile.pinned_repositories # Up to 6 pinned repos
profile.active_repositories # 5 recent active repos
```

### Language Data

```ruby
profile.language_breakdown   # Hash of language => count
profile.top_languages(5)    # Top 5 languages with counts
```

### Activity Data

```ruby
profile.last_active         # Last activity timestamp
profile.total_events        # Total events in last 90 days
profile.event_breakdown     # Event type breakdown hash
```

### Social & Organization Data

```ruby
profile.twitter_account     # Twitter social account
profile.bluesky_account     # Bluesky social account
profile.organization_names  # Array of organization names
profile.social_accounts_by_provider # Grouped social accounts
```

### README Content

```ruby
profile.readme_content      # Full README content
profile.has_readme?         # Boolean check
```

### Utility Methods

```ruby
profile.display_name        # Name or login fallback
profile.github_profile_url # GitHub profile URL
profile.needs_sync?         # Check if sync needed
profile.data_completeness  # Completeness metrics
```

## Data Completeness Metrics

The `data_completeness` method provides insights into profile data quality:

```ruby
{
  required_completeness: 100.0,    # Required fields completion %
  optional_completeness: 75.0,     # Optional fields completion %
  has_repositories: true,          # Has repository data
  has_organizations: true,          # Has organization data
  has_social_accounts: false,      # Has social account data
  has_readme: true                 # Has README content
}
```

## Scopes & Queries

### Available Scopes

```ruby
Profile.for_login('username')      # Case-insensitive login search
Profile.hireable                   # Users open to opportunities
Profile.recently_active            # Active in last week
```

### Common Queries

```ruby
# Find by login (case-insensitive)
Profile.for_login('loftwah')

# Find hireable developers
Profile.hireable

# Find recently active profiles
Profile.recently_active

# Get profiles with specific language
Profile.joins(:profile_languages)
       .where(profile_languages: { name: 'Ruby' })

# Get profiles in specific organization
Profile.joins(:profile_organizations)
       .where(profile_organizations: { login: 'rails' })
```

## API Rate Limits

- **GitHub App Authentication**: 15,000 requests/hour
- **User OAuth**: 5,000 requests/hour
- **GraphQL**: 5,000 points/hour

The app uses GitHub App authentication for higher rate limits and better reliability.

## Data Freshness

- **Sync Frequency**: Profiles are synced when accessed if older than 1 hour
- **Manual Refresh**: `bin/rails 'profiles:refresh[username]'`
- **Bulk Refresh**: `bin/rails profiles:refresh_all`

## GitHub Permissions & Access

### OAuth Scopes (User Authentication)

- **`read:user`**: Access to user profile data, followers, and following counts
- **`user:email`**: Access to user's email addresses (if publicly visible)

### GitHub App Permissions (API Access)

- **Email addresses**: Read access to user email addresses
- **Followers**: Read access to follower lists and counts

## Privacy & Security

- Only **public** GitHub data is collected
- No private repository information
- Email addresses only if publicly visible
- All data stored locally in SQLite database
- No data shared with third parties

## Example Profile Data

Here's what a complete profile looks like:

```ruby
profile = Profile.find_by(login: 'loftwah')

# Basic Info
profile.name                    # "Dean Lofts"
profile.login                   # "loftwah"
profile.bio                     # "Builder, entrepreneur, Ruby enthusiast"
profile.company                 # "TecHub"
profile.location                # "Perth, Australia"
profile.followers               # 1140
profile.following               # 524
profile.public_repos            # 356

# Repositories
profile.top_repositories.count  # 5
profile.pinned_repositories.count # 6
profile.active_repositories.count # 5

# Languages
profile.language_breakdown      # {"Ruby" => 50, "JavaScript" => 30, "Python" => 20}
profile.top_languages(3)        # Top 3 languages with counts

# Activity
profile.last_active            # 2025-10-04 12:00:00 UTC
profile.total_events           # 169
profile.event_breakdown        # {"PushEvent" => 101, "PullRequestEvent" => 29}

# Organizations
profile.organization_names     # ["Rails", "Ruby Australia"]
profile.organization_logins    # ["rails", "rubyaustralia"]

# Social
profile.twitter_account        # Twitter social account object
profile.bluesky_account        # Bluesky social account object

# README
profile.readme_content         # Full markdown content
profile.has_readme?           # true

# Completeness
profile.data_completeness     # Completeness metrics hash
```

## Design Considerations

### For Trading Card Design

1. **Avatar**: Always available (local or GitHub URL)
2. **Display Name**: Fallback to login if name missing
3. **Bio**: May be empty, provide fallback text
4. **Stats**: Always numeric, good for visual elements
5. **Languages**: Ranked by usage, perfect for skill indicators
6. **Repositories**: Categorized by type and popularity
7. **Activity**: Shows engagement level and recency

### For Directory/Listing Views

1. **Search**: By login, name, company, location
2. **Filter**: By languages, organizations, hireable status
3. **Sort**: By followers, activity, repository count
4. **Group**: By organizations, languages, location

### For API Endpoints

1. **Profile Data**: Complete profile information
2. **Repository Data**: Categorized repository lists
3. **Activity Data**: Recent activity and engagement
4. **Social Data**: Connected social media accounts

## Next Phase Design Opportunities

Based on this data structure, here are design opportunities for the next phase:

1. **Enhanced Trading Cards**: Use language breakdown, activity patterns, and organization data
2. **Advanced Filtering**: Filter by multiple criteria (languages, organizations, activity)
3. **Social Integration**: Display connected social media accounts
4. **Activity Visualization**: Show recent activity patterns and engagement
5. **Organization Showcase**: Highlight organization memberships
6. **README Integration**: Display profile README content
7. **Data Completeness Indicators**: Show profile completeness scores
8. **Trending Profiles**: Based on recent activity and engagement

This comprehensive data structure provides a solid foundation for building rich, engaging profile
experiences that go beyond basic GitHub profile information.
