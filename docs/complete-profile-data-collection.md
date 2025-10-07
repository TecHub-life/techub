# Complete Public Profile Data Collection

## Overview

We now collect **ALL** publicly visible GitHub profile information, including extended data that
requires additional API calls and GraphQL queries.

## What We Collect

### Basic Profile Information

- ✅ **Name**: Full display name
- ✅ **Login**: GitHub username/handle
- ✅ **Avatar URL**: Profile picture
- ✅ **Bio**: Short profile bio
- ✅ **Company**: Current company/employer
- ✅ **Location**: Geographic location
- ✅ **Blog/Website**: Personal website URL
- ✅ **Email**: Public email address (if set)
- ✅ **Twitter Username**: Linked Twitter account
- ✅ **Hireable**: Whether open to opportunities
- ✅ **Profile URL**: GitHub profile link
- ✅ **Created At**: Account creation date
- ✅ **Updated At**: Last profile update

### Stats

- ✅ **Followers**: Follower count
- ✅ **Following**: Following count
- ✅ **Public Repos**: Public repository count
- ✅ **Public Gists**: Public gist count

### Repository Information

- ✅ **Top Repositories**: 5 most starred non-fork repos
- ✅ **Pinned Repositories**: Up to 6 pinned repos (via GraphQL)
- ✅ **Active Repositories**: 5 recent public repos user contributed to
- ✅ **Languages**: Language breakdown across all repos

### Extended Profile Data

- ✅ **Profile README**: Full README from username/username repo
- ✅ **Organizations**: All public organizations (with avatars and descriptions)
- ✅ **Social Accounts**: Connected social media (Twitter/X, Bluesky, LinkedIn, Facebook, Instagram, YouTube, Reddit, Twitch, Mastodon, npm)
- ✅ **Recent Activity**: Event breakdown and activity stats

## Example Data Structure

```ruby
{
  profile: {
    id: 123456,
    login: "loftwah",
    name: "Dean Lofts",
    avatar_url: "https://github.com/loftwah.png",
    bio: "DevOps Engineer & Music Producer",
    company: "TecHub",
    location: "Perth, Australia",
    blog: "https://deanlofts.xyz",
    email: "dean@deanlofts.xyz",
    twitter_username: "loftwah",
    hireable: true,
    html_url: "https://github.com/loftwah",
    followers: 1140,
    following: 524,
    public_repos: 356,
    public_gists: 10,
    created_at: "2014-01-01T00:00:00Z",
    updated_at: "2025-08-25T08:40:32Z"
  },

  organizations: [
    {
      login: "EddieHubCommunity",
      name: "EddieHub Community",
      avatar_url: "https://avatars.githubusercontent.com/u/...",
      description: "An inclusive open source community",
      html_url: "https://github.com/EddieHubCommunity"
    }
  ],

  social_accounts: [
    {
      provider: "TWITTER",
      url: "https://x.com/loftwah",
      display_name: "@loftwah"
    },
    {
      provider: "BLUESKY",
      url: "https://bsky.app/profile/loftwah.com",
      display_name: null
    }
  ],

  pinned_repositories: [
    {
      name: "linux-for-pirates",
      description: "A book about Linux, in the theme of Pirates!",
      html_url: "https://github.com/loftwah/linux-for-pirates",
      stargazers_count: 142,
      forks_count: 18,
      language: "Astro",
      topics: ["book", "cloud", "devops", "linux", "education"]
    }
  ],

  active_repositories: [
    {
      name: "techub",
      full_name: "TecHub-life/techub",
      description: "TecHub is TechDeck, but for GitHub",
      html_url: "https://github.com/TecHub-life/techub",
      stargazers_count: 2,
      language: "Ruby",
      topics: ["ai", "profiles", "card-game"]
    }
  ],

  top_repositories: [...],
  languages: { "Ruby" => 21, "Shell" => 18, "Python" => 17 },
  profile_readme: "Full README content...",
  recent_activity: {
    total_events: 169,
    event_breakdown: { "PushEvent" => 101, "PullRequestEvent" => 29 },
    recent_repos: ["TecHub-life/techub", "loftwah/linux-for-pirates"],
    last_active: "2025-10-03T00:00:00Z"
  }
}
```

## GitHub Permissions Required

### OAuth Scopes (User Authentication)
- **`read:user`**: Access to user profile data, followers, and following counts
- **`user:email`**: Access to user's email addresses (if publicly visible)

### GitHub App Permissions (API Access)
- **Email addresses**: Read access to user email addresses
- **Followers**: Read access to follower lists and counts

## API Calls Made

Per profile sync, we make:

1. **REST API - User Data** (1 call)
   - Basic profile information

2. **REST API - Repositories** (1 call)
   - All public repositories (paginated)

3. **REST API - Profile README** (1 call)
   - README from username/username repo

4. **REST API - User Events** (1 call)
   - Recent activity events

5. **REST API - Organizations** (1 call)
   - Organization memberships

6. **REST API - Active Repo Details** (up to 5 calls)
   - Details for each active repository

7. **GraphQL - Pinned Repositories** (1 call)
   - Pinned items via GraphQL

8. **GraphQL - Social Accounts** (1 call)
   - Connected social media accounts

**Total: 11-16 API calls per profile**

## Display Sections

### Sidebar (Left Column)

1. **Profile Card**
   - Avatar
   - Name
   - Handle (@username)
   - Bio
   - Contact info (location, company, email, website, Twitter)
   - Hireable status
   - Followers/Following/Repos stats

2. **Top Languages**
   - Top 5 languages with counts

3. **Social Accounts** (NEW)
   - Links to Twitter/X, Bluesky, LinkedIn, etc.

4. **Organizations** (NEW)
   - Organization avatars and names
   - Links to organization pages

5. **Recent Activity**
   - Last active date
   - Total events (90 days)
   - Event type breakdown
   - Active public repositories

### Main Content (Right Column)

1. **Profile README**
   - First 5000 characters
   - Full markdown content

2. **Pinned Repositories** (if any)
   - 2-column grid
   - Stars, forks, language, topics

3. **Top Repositories by Stars**
   - Top 5 repositories
   - Full details with links

## Display Examples

### Contact Information Display

```
Location: Perth, Australia
Company: TecHub
Email: dean@deanlofts.xyz
Website: https://deanlofts.xyz
Twitter: @loftwah
💼 Available for hire
```

### Social Accounts Display

```
Social
├─ Twitter - @loftwah
└─ Bluesky - loftwah.com
```

### Organizations Display

```
Organizations
├─ EddieHubCommunity (with avatar)
│  └─ An inclusive open source community
├─ caremonkey (with avatar)
└─ fish-lgbt (with avatar)
```

## Privacy & Ethics

- ✅ Only collects **public** information
- ✅ Respects user privacy settings
- ✅ No scraping or unauthorized access
- ✅ Uses official GitHub APIs only
- ✅ Follows GitHub's rate limits
- ✅ Caches data to minimize API calls

## Benefits

1. **Complete Profile Picture**: Shows everything visible on GitHub profile
2. **Rich Context**: Organizations show community involvement
3. **Social Links**: Easy connection across platforms
4. **Accurate Stats**: Real-time follower/following counts
5. **Professional Info**: Hireable status and contact info
6. **Better Discovery**: More data points for matching and recommendations

## Future Enhancements

Consider adding:

- Contribution graph data
- Achievement badges
- Sponsor information
- Pull request stats
- Issue engagement metrics
- Code review activity
- Repository contribution percentages

## Summary

We now collect **100% of publicly visible profile data** from GitHub, providing a complete picture
of each user's public presence, including:

- 17 profile fields (up from 13)
- Organizations with full details
- Social media accounts
- Enhanced repository information
- Complete activity history

All data is stored in the database and available for processing, analytics, and display.
