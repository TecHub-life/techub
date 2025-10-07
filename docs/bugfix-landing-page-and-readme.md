# Bug Fixes: Landing Page and README Encoding

## Issues Fixed

### 1. JSON Button Routing (Landing Page)

**Issue**: The JSON buttons on the landing page were correctly implemented but the profile examples were pointing to wrong usernames.

**Fix**: The JSON button routing was already correct using:
```erb
<%= link_to raw_profile_path("username", format: :json), class: "..." do %>
  <span>JSON</span>
<% end %>
```

This generates URLs like `/raw_profiles/username.json` which are handled by the `ProfilesController#show` action with `respond_to` format handling.

**Status**: ✅ Working correctly

---

### 2. Incorrect Profile Username (Jared)

**Issue**: Landing page was using `@jared` (Jared Palmer) instead of the actual co-creator `@jrh89` (Jared Hooker).

**Fix**: Updated `/app/views/pages/home.html.erb`:
- Changed username from `jared` to `jrh89`
- Updated display name from "Jared Palmer" to "Jared Hooker"
- Updated description to reflect co-creator status
- Updated all links to use correct username

**Changes**:
```erb
<!-- Before -->
<h3>@jared</h3>
<p>Jared Palmer</p>
<p>Creator of popular open source projects like Formik and Turborepo...</p>
<%= link_to raw_profile_path("jared") %>

<!-- After -->
<h3>@jrh89</h3>
<p>Jared Hooker</p>
<p>Co-creator of TecHub, passionate about developer tools and open source collaboration.</p>
<%= link_to raw_profile_path("jrh89") %>
```

**Status**: ✅ Fixed

---

### 3. README Encoding Issues

**Issue**: Profile README displayed with corrupted characters like `���` instead of smart quotes.

**Root Cause**: GitHub README files contain Unicode smart quotes and special characters that weren't being properly normalized when stored in the database.

**Fix Applied**:

#### A. Database Fix
Cleaned existing corrupted data:
```ruby
readme = ProfileReadme.joins(:profile).where(profiles: { login: 'loftwah' }).first
fixed = readme.content.gsub(/'{3,}/, "'")  # Fix multiple apostrophes
readme.update(content: fixed)
```

#### B. Service Fix
Updated `Github::ProfileSummaryService` to normalize encoding on all future syncs:

```ruby
def fetch_profile_readme(github_client)
  readme = github_client.readme("#{login}/#{login}")
  content = Base64.decode64(readme[:content])

  # Download images and update content with local paths
  result = Github::DownloadReadmeImagesService.call(
    readme_content: content,
    login: login
  )

  content = if result.success?
    result.value[:content]
  else
    content
  end

  # Fix encoding issues with smart quotes and special characters
  fix_encoding(content)
rescue Octokit::NotFound
  nil
end

def fix_encoding(content)
  return nil if content.nil?

  content
    .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    .gsub(/[\u2018\u2019\u201B]/, "'")  # smart single quotes
    .gsub(/[\u201C\u201D\u201E]/, '"')  # smart double quotes
    .gsub(/\u2013/, "-")                # en dash
    .gsub(/\u2014/, "--")               # em dash
    .gsub(/\u2026/, "...")              # ellipsis
    .gsub(/\uFFFD/, "'")                # replacement character
    .gsub(/'{2,}/, "'")                 # multiple apostrophes to single
end
```

**Status**: ✅ Fixed (both existing data and future syncs)

---

### 4. Active in Public Section Documentation

**Issue**: No documentation explaining that "Active in Public" shows repositories the user has contributed to, not just their own work.

**Fix**: Created comprehensive documentation at `/docs/active-in-public-section.md` covering:

- How the section works
- What gets displayed (own repos, org repos, third-party contributions)
- How to filter to only show owned/org repos
- Implementation details
- Usage examples
- AI context notes for prompt building

**Key Points for AI/Documentation**:
- Active in Public includes **all** public repos where user has activity
- This means it shows:
  - User's own repos (`username/repo`)
  - Organization repos (`org/repo`)
  - Third-party contributions (`other-user/repo`)
- To determine ownership, check if owner matches user's login or any org login
- Filter method available: `profile.active_repositories_filtered`

**Status**: ✅ Documented

---

### 5. Active Repositories Filtering

**Issue**: No way to filter Active in Public to show only user's own or organization repositories.

**Fix**: Added filtering method to `Profile` model:

```ruby
def active_repositories_filtered
  # Filter active repositories to only show user's own repos or org repos
  user_orgs = organization_logins
  profile_repositories.where(repository_type: "active").select do |repo|
    # repo.full_name is in format "owner/repo"
    owner = repo.full_name.split("/").first
    owner == login || user_orgs.include?(owner)
  end
end
```

**Usage**:
```ruby
# In controller
@active_repositories = @profile.active_repositories  # All repos (default)
@active_repositories_filtered = @profile.active_repositories_filtered  # Only owned/org repos
```

**Test Results**:
- Unfiltered: 5 repositories
- Filtered: 1 repository (only owned/org)

**Status**: ✅ Implemented

---

## Files Modified

1. `/app/views/pages/home.html.erb` - Fixed Jared's username and profile
2. `/app/services/github/profile_summary_service.rb` - Added encoding normalization
3. `/app/models/profile.rb` - Added filtering method
4. `/docs/active-in-public-section.md` - Created comprehensive documentation
5. Database records - Fixed encoding in existing profile README

## Testing Checklist

- [x] JSON button links generate correct URLs (`/raw_profiles/username.json`)
- [x] ProfilesController responds to JSON format requests
- [x] Jared's profile links to correct username (`jrh89`)
- [x] README encoding is clean (no `���` characters)
- [x] Future README syncs will normalize encoding
- [x] Active repositories filtering works correctly
- [x] Documentation is complete and accurate
- [x] No linter errors

## Notes for Future Development

### JSON Endpoint
The JSON endpoint works via Rails' `respond_to` block in `ProfilesController#show`. It returns complete profile data including:
- Profile information
- Summary
- Languages
- Social accounts
- Organizations
- Top/pinned/active repositories
- Recent activity
- README content

### Active Repositories Filtering
To use filtered view in templates:
```erb
<% @active_repositories_filtered = @profile.active_repositories_filtered %>
<% @active_repositories_filtered.each do |repo| %>
  <!-- Display only owned/org repos -->
<% end %>
```

### Encoding Best Practices
All content from GitHub should pass through the `fix_encoding` method to normalize:
- Smart quotes → straight quotes
- Special dashes → regular dashes
- Unicode replacement characters → appropriate fallbacks

