# Motifs Issues Resolution Summary

This document summarizes the issues reported and the solutions implemented.

## Issues Reported

1. The Everyman and The Innocent archetypes show broken images in production
2. Other archetypes display correctly
3. Duplicate "Overwrite lore" checkbox on `/ops/motifs` page
4. Ops panel credentials cached in Chrome, preventing login with new credentials
5. Need a way to verify and check image issues

## Root Cause Analysis

### Broken Images for Specific Archetypes

The image resolution system works in this order:

1. Database URL (`Motif.image_1x1_url`)
2. Asset pipeline file (`app/assets/images/archetypes/{slug}.{png|jpg|jpeg|webp}`)
3. Placeholder image (`app/assets/images/android-chrome-512x512.jpg`)

**Local verification shows:**

- Only `the-sage.jpg` exists in `app/assets/images/archetypes/`
- The Innocent and The Everyman have NO database URLs or asset files
- They should fall back to placeholder

**Likely production issue:**

- The production database may have invalid/broken URLs stored for these two specific archetypes
- Or there's browser/CDN caching of old broken URLs

### Duplicate Checkbox Confusion

The two "Overwrite lore" checkboxes are actually intentional - they belong to two separate forms:

1. "Seed from Catalog" form - overwrites with catalog descriptions
2. "Generate Missing Lore (Gemini)" form - overwrites with AI-generated lore

However, the UI made them look like duplicates due to poor visual separation.

## Solutions Implemented

### 1. Image Verification Tool ✅

Created new rake tasks in `lib/tasks/motifs_verify.rake`:

**Verify all motif images:**

```bash
bin/rails motifs:verify_images
```

This checks:

- Database URLs for validity (proper URI format)
- Asset file existence
- Reports which motifs use placeholders

**Fix broken URLs automatically:**

```bash
bin/rails motifs:verify_images FIX=1
```

This clears any invalid database URLs, forcing fallback to assets or placeholder.

**List all image sources:**

```bash
bin/rails motifs:list_images
```

Shows where each motif gets its image from (DB, Asset, or Placeholder).

### 2. Improved Ops Panel UI ✅

Updated `/apps/views/ops/motifs/index.html.erb`:

**Changes:**

- Separated the two forms into distinct visual sections
- Added section headers: "Seed from Catalog" and "Generate Lore (AI)"
- Improved layout with grid and better spacing
- Made checkboxes and labels larger and clearer
- Added colored borders to distinguish the two actions
- Added an "Image Verification" info box with instructions

**Result:** The two "Overwrite lore" checkboxes are now clearly part of separate operations.

### 3. Chrome Credential Cache Documentation ✅

Created `docs/ops-auth-clear-cache.md` with 7 methods to clear cached credentials:

**Quick fixes:**

1. Use incognito mode (works immediately)
2. Visit `https://logout@techub.life/ops` to force re-authentication
3. Chrome Settings → Passwords → Remove specific site credentials

**See the full doc for all methods.**

### 4. Updated Documentation ✅

**Updated `docs/motifs.md`:**

- Added comprehensive troubleshooting section
- Image verification instructions
- Common causes of broken images
- Commands to run in production

**Updated `docs/ops-troubleshooting.md`:**

- Added quick reference to credential caching fix
- Link to detailed auth clearing guide

## Action Required (Production)

To fix the broken images in production, run these commands:

### Step 1: Verify the Issue

```bash
# SSH into production or use Kamal
bin/kamal app exec "bin/rails motifs:verify_images"
```

This will show you which motifs have broken/invalid database URLs.

### Step 2: Fix Broken URLs

```bash
bin/kamal app exec "bin/rails motifs:verify_images FIX=1"
```

This will clear any invalid URLs from the database.

### Step 3: Verify the Fix

```bash
# List all image sources
bin/kamal app exec "bin/rails motifs:list_images"
```

### Step 4: Clear Browser Cache

If images still appear broken after fixing the database:

1. Clear your browser cache (hard refresh: Ctrl+Shift+R or Cmd+Shift+R)
2. Or test in incognito mode
3. May also need to clear CDN cache if using one

### Step 5: Long-term Solution (Optional)

If you want these archetypes to have proper images instead of placeholders:

1. Create/obtain images for the missing archetypes
2. Name them with the correct slug:
   - `the-innocent.jpg` (or .png, .jpeg, .webp)
   - `the-everyman.jpg` (or .png, .jpeg, .webp)
3. Place them in `app/assets/images/archetypes/`
4. Commit and deploy:
   ```bash
   git add app/assets/images/archetypes/
   git commit -m "Add archetype images for The Innocent and The Everyman"
   bin/kamal deploy
   ```

## Chrome Credentials Issue - Quick Fix

To clear cached ops panel credentials in Chrome:

**Method 1 (Immediate):** Open incognito window and navigate to ops panel

**Method 2 (Force logout):** Visit: `https://logout@techub.life/ops`

**Method 3 (Clear specific credentials):**

1. Chrome Settings → `chrome://settings/passwords`
2. Search for `techub.life`
3. Remove the entry
4. Restart Chrome

For all 7 methods, see `docs/ops-auth-clear-cache.md`

## Testing the Fixes

### Local Testing

```bash
# Verify the rake task works
bin/rails motifs:verify_images

# Check ops panel UI improvements
bin/rails server
# Visit: http://localhost:3000/ops/motifs
```

### Production Testing

```bash
# Run verification in production
bin/kamal app exec "bin/rails motifs:verify_images"

# Fix any broken URLs
bin/kamal app exec "bin/rails motifs:verify_images FIX=1"

# Verify the archetypes page
# Visit: https://techub.life/archetypes
```

## Summary

All issues have been addressed:

1. ✅ Created verification tool to identify and fix broken image URLs
2. ✅ Improved ops/motifs UI to clarify the two separate forms
3. ✅ Documented multiple methods to clear Chrome's auth cache
4. ✅ Added image verification helper directly in ops panel
5. ✅ Updated all relevant documentation

The broken images for The Innocent and The Everyman are likely caused by invalid database URLs in
production. Run the verification task with `FIX=1` to resolve this.
