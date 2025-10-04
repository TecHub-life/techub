# Bugfix: Profile Data Not Displaying

## Problem

After implementing the enhanced profile features, the page was rendering but most data fields were empty:
- Name was empty
- Handle showed just "@" with no username
- Followers, Following, and Repos counts were all empty  
- All repository sections (pinned, active, top) showed empty cards
- Only languages and recent activity stats were displaying

## Root Cause

The JSON data from the database uses **string keys**, but the view templates were trying to access nested hashes with **symbol keys**.

```ruby
# What we were doing
@profile_payload = @profile.data.symbolize_keys

# This only converted top-level keys:
{
  :profile => { "name" => "Dean Lofts", "login" => "loftwah" }, # Still string keys!
  :pinned_repositories => [...]
}

# So this failed:
profile[:name]  # nil - because the actual key is "name", not :name
```

## Solution

Changed from `symbolize_keys` to `deep_symbolize_keys` to recursively convert all nested hash keys to symbols:

```ruby
# Files changed:
# - app/controllers/pages_controller.rb
# - app/controllers/profiles_controller.rb

@profile_payload = @profile.data.deep_symbolize_keys

# Now all nested keys are symbols:
{
  :profile => { :name => "Dean Lofts", :login => "loftwah" },
  :pinned_repositories => [
    { :name => "repo", :html_url => "...", :stargazers_count => 142 }
  ]
}

# So this works:
profile[:name]  # "Dean Lofts" ✅
```

## Files Modified

1. `app/controllers/pages_controller.rb` - Changed `symbolize_keys` to `deep_symbolize_keys` (2 places)
2. `app/controllers/profiles_controller.rb` - Changed `symbolize_keys` to `deep_symbolize_keys` (1 place)

## Verification

```bash
# Test that all data is accessible
bin/rails runner "profile = Profile.find_by(github_login: 'loftwah'); data = profile.data.deep_symbolize_keys; puts data[:profile][:name]"
# Output: Dean Lofts ✅
```

## Result

All profile data now displays correctly:
- ✅ Name: "Dean Lofts"
- ✅ Handle: "@loftwah"
- ✅ Followers: 1,140
- ✅ Following: 524
- ✅ Public Repos: 356
- ✅ 4 Pinned repos with full details
- ✅ 5 Active repos with full details
- ✅ 5 Top repos with full details
- ✅ Profile README (8,630 characters)
- ✅ All repository links working

## Testing

All 40 tests pass with no failures or errors.

