# Active in Public Section

## Overview

The "Active in Public" section displays repositories that the user has recently contributed to based on their public GitHub activity events.

## How It Works

### Data Collection

The active repositories are determined by:

1. Fetching the user's recent public events (last 100 events) via the GitHub API
2. Extracting repository names from those events
3. Fetching detailed information for the top 5 most recent repositories
4. Storing them with `repository_type: "active"` in the database

### What Gets Displayed

The section shows **any public repository** the user has contributed to, including:

- ✅ User's own repositories (`username/repo-name`)
- ✅ Organization repositories (`org-name/repo-name`)
- ✅ Third-party repositories the user has contributed to (`other-user/repo-name`)

### Filtering Options

By default, all public repositories where the user has been active are shown. However, you can filter to only show repositories owned by the user or their organizations using:

```ruby
# In the controller or view
@active_repositories_filtered = @profile.active_repositories_filtered
```

This will only include repositories where:
- The repository owner matches the user's GitHub login, OR
- The repository owner is one of the user's public organizations

### Example

For user `loftwah` who is a member of organizations `TecHub-life` and `example-org`:

**Without filtering** (shows all):
- `TecHub-life/techub` ✅ (user's org)
- `loftwah/devops-refresher` ✅ (user's repo)
- `stakater/Reloader` ✅ (third-party contribution)
- `gcui-art/suno-api` ✅ (third-party contribution)

**With filtering** (filtered to own/org repos):
- `TecHub-life/techub` ✅ (user's org)
- `loftwah/devops-refresher` ✅ (user's repo)
- `stakater/Reloader` ❌ (not owned by user or their org)
- `gcui-art/suno-api` ❌ (not owned by user or their org)

## Implementation Details

### Database Schema

Active repositories are stored in the `profile_repositories` table with:
- `repository_type: "active"`
- `full_name`: The full repository name (`owner/repo-name`)
- Standard repository metadata (description, stars, language, etc.)

### Service Logic

The `Github::ProfileSummaryService` class handles fetching active repositories:

```ruby
def fetch_active_repo_details(github_client, recent_activity)
  return [] unless recent_activity && recent_activity[:recent_repos].present?

  active_repos = []
  recent_activity[:recent_repos].first(5).each do |repo_full_name|
    repo = github_client.repository(repo_full_name)
    next if repo[:private]  # Skip private repos

    active_repos << {
      name: repo[:name],
      full_name: repo[:full_name],
      description: repo[:description],
      html_url: repo[:html_url],
      stargazers_count: repo[:stargazers_count],
      forks_count: repo[:forks_count],
      language: repo[:language],
      topics: Array(repo[:topics]),
      owner_login: repo.dig(:owner, :login)
    }
  end

  active_repos
end
```

### Model Methods

The `Profile` model provides two methods:

```ruby
# Returns all active repositories
def active_repositories
  profile_repositories.where(repository_type: "active")
end

# Returns only user's own repos or org repos
def active_repositories_filtered
  user_orgs = organization_logins
  profile_repositories.where(repository_type: "active").select do |repo|
    owner = repo.full_name.split("/").first
    owner == login || user_orgs.include?(owner)
  end
end
```

## Usage in Views

To display active repositories:

```erb
<% if @active_repositories.present? && @active_repositories.any? %>
  <div>
    <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase mb-2">
      Active in (Public)
    </p>
    <div class="space-y-2">
      <% @active_repositories.each do |repo| %>
        <div class="text-xs">
          <a href="<%= repo.html_url %>" target="_blank" class="text-blue-600 dark:text-blue-400 hover:underline font-medium">
            <%= repo.full_name %>
          </a>
          <% if repo.description.present? %>
            <p class="text-slate-600 dark:text-slate-400 mt-0.5">
              <%= repo.description.truncate(60) %>
            </p>
          <% end %>
          <div class="flex items-center gap-2 mt-0.5 text-slate-500 dark:text-slate-400">
            <span>⭐ <%= repo.stargazers_count %></span>
            <% if repo.language.present? %>
              <span><%= repo.language %></span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

## AI Context Notes

When building prompts for AI tools or analyzing profile data:

**Important**: The "Active in Public" section may include repositories that the user does **not** own. These are public repositories where the user has contributed code, opened issues, or participated in discussions.

To determine ownership:
1. Check if the repository owner (first part of `full_name`) matches the user's `login`
2. Check if the repository owner matches any of the user's organization `login` values
3. If neither, it's a third-party contribution

Example filtering in a prompt:

```
When analyzing this user's work, note that repositories in "Active in Public" 
include both owned and contributed projects. The user owns:
- Repositories where owner = "loftwah"
- Repositories where owner = "TecHub-life" (user's org)

Third-party contributions should be noted separately.
```

## Future Enhancements

Potential improvements:
- Add a UI toggle to show/hide third-party contributions
- Display a badge or indicator for "owned" vs "contributed"
- Track contribution type (commits, PRs, issues) per repository
- Add time-based filtering (active this week, this month, etc.)

