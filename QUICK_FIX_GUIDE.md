# Quick Fix Guide for Reported Issues

## Issue 1: The Everyman & The Innocent Show Broken Images

**Fix in production:**

```bash
# Check what's wrong
bin/kamal app exec "bin/rails motifs:verify_images"

# Fix it automatically
bin/kamal app exec "bin/rails motifs:verify_images FIX=1"

# Verify the fix
bin/kamal app exec "bin/rails motifs:list_images"
```

**Then clear your browser cache** (Ctrl+Shift+R) or test in incognito mode.

## Issue 2: Chrome Caching Old Ops Panel Credentials

**Quick fix (works immediately):**

Visit this URL to force Chrome to forget and re-prompt:

```
https://logout@techub.life/ops
```

**Or use incognito mode** - this always works.

**Permanent fix:**

1. Chrome → Settings → `chrome://settings/passwords`
2. Search for "techub.life"
3. Remove the saved entry
4. Restart Chrome

See `docs/ops-auth-clear-cache.md` for 7 different methods.

## Issue 3: Duplicate Overwrite Lore Checkbox

**Fixed!** The ops/motifs page now has:

- Clear visual separation between the two forms
- Section headers explaining what each does
- The two checkboxes are now obviously for different operations

Visit `/ops/motifs` to see the improved UI.

## Issue 4: How to Verify Images

**New tools added:**

```bash
# Check all motif images (shows which use DB, assets, or placeholder)
bin/rails motifs:verify_images

# Fix broken database URLs automatically
bin/rails motifs:verify_images FIX=1

# List all image sources
bin/rails motifs:list_images
```

**Also added to ops panel:** There's now an info box at `/ops/motifs` explaining how to run these
commands.

## What Changed

### Files Added:

- `lib/tasks/motifs_verify.rake` - Image verification rake tasks
- `docs/ops-auth-clear-cache.md` - Complete guide to clearing auth cache
- `MOTIFS_ISSUES_RESOLUTION.md` - Detailed explanation of all issues and fixes
- `QUICK_FIX_GUIDE.md` - This file

### Files Modified:

- `app/views/ops/motifs/index.html.erb` - Improved UI with better form separation and verification
  info
- `docs/motifs.md` - Added troubleshooting section
- `docs/ops-troubleshooting.md` - Added credential caching reference

## Testing Locally

```bash
# Test the verification tools
bin/rails motifs:verify_images
bin/rails motifs:list_images

# Start server and check ops panel
bin/rails server
# Visit: http://localhost:3000/ops/motifs
```

## Next Steps

1. Run the verification task in production to fix broken URLs
2. Clear your browser cache or use incognito to test
3. Consider adding actual images for missing archetypes (see `MOTIFS_ISSUES_RESOLUTION.md`)

## Questions?

See the detailed docs:

- Image issues: `docs/motifs.md` (Troubleshooting section)
- Auth issues: `docs/ops-auth-clear-cache.md`
- Complete analysis: `MOTIFS_ISSUES_RESOLUTION.md`
