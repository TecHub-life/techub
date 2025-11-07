# Testing Summary - JavaScript & Stimulus

## What We Added

### 1. Importmap Integrity Check (`bin/check-importmap`)

**Purpose**: Validates that all JavaScript imports are properly configured before deployment.

**What it checks**:

- ✅ All imports in `application.js` are pinned in `importmap.rb`
- ✅ All Stimulus controllers are accessible via `pin_all_from`
- ✅ Critical dependencies (@hotwired/turbo-rails, @hotwired/stimulus, etc.) are present
- ✅ Custom modules (techub_console) are pinned and files exist

**Exit codes**:

- `0` = Success (all checks passed)
- `1` = Failure (missing imports or files)

**Runs in CI**: Yes, automatically via `config/ci.rb` line 64-66

### 2. System Tests for Stimulus Tabs (`test/system/stimulus_tabs_test.rb`)

**Purpose**: Verify that Stimulus tabs controller loads and works correctly.

**What it tests**:

- ✅ Profile pages load with correct title and URL
- ✅ Tabs controller exists in DOM (`data-controller='tabs'`)
- ✅ All 6 tab buttons are present (Profile, Overview, Cards, Repos, Activity, Stats)
- ✅ Tab panels exist in DOM with correct data attributes
- ✅ Stimulus data attributes are correctly set (`data-tabs-target`, `data-tabs-id`, `data-action`)
- ✅ Page content renders (bio text visible)

**Test count**: 3 tests

- `test_profile_page_has_tabs_controller_and_tab_elements`
- `test_tabs_are_clickable_and_have_correct_data_attributes`
- `test_profile_page_renders_with_all_content`

**Runs in CI**: Yes, automatically via `bin/rails test:system`

### 3. Documentation (`docs/testing-javascript-stimulus.md`)

**Purpose**: Guide for writing JavaScript and Stimulus tests in TecHub.

**Contents**:

- How to write system tests for Stimulus controllers
- How to test vanilla JavaScript
- Best practices and patterns
- Troubleshooting guide
- Examples for tabs, lightbox, and other features

## CI Integration

All checks run automatically in the CI pipeline (`config/ci.rb`):

```ruby
run!("importmap integrity") do
  system("ruby bin/check-importmap")
end

# ... other checks ...

run!("system test") { system("bin/rails test:system") }
```

Each step:

1. Prints `== label ==` before running
2. Returns truthy value on success
3. Exits with code 1 on failure (stops CI)
4. Shows `All green!` if everything passes

## Key Learnings

### Headless Chrome Limitations

- **Gradient text is invisible**: `text-transparent` with `bg-clip-text` doesn't render text for
  Capybara
- **Solution**: Use `page.title` and `assert_current_path` instead of checking gradient text
- **Workaround**: Use `visible: :all` to find elements regardless of CSS visibility

### Test Data Requirements

- Profiles must have `listed: true` to be found by controller
- Profiles need `preferences` record created (view requires it)
- Profile cards need all required fields (attack, defense, speed, vibe, archetype, spirit_animal)

### OpenTelemetry in Tests

- Set `ENV["OTEL_SDK_DISABLED"] = "true"` before Rails loads
- Stub Honeycomb API calls with WebMock
- Prevents hanging on external HTTP requests during tests

## Running Tests Locally

```bash
# Run all system tests
bin/rails test:system

# Run specific test file
bin/rails test:system test/system/stimulus_tabs_test.rb

# Run specific test
bin/rails test:system test/system/stimulus_tabs_test.rb:6

# Run importmap check
ruby bin/check-importmap

# Run full CI suite
ruby config/ci.rb
```

## Future Enhancements

### Settings Page Test (Skipped)

Authentication in system tests is complex. To implement:

1. Create proper session helper for Selenium driver
2. Use `ProfileOwnership` model (not `owner` attribute)
3. Test all 6 settings tabs (general, backgrounds, assets, showcase, styles, secrets)

### JavaScript Execution Tests

Currently we test DOM structure, not JavaScript execution. To test actual tab switching:

1. Use `execute_script` to trigger clicks
2. Wait for DOM changes with `assert_selector` timeouts
3. Verify `aria-selected` and `hidden` class changes
4. May be flaky in headless Chrome - document carefully

## Files Modified

### New Files

- `bin/check-importmap` - Importmap validation script
- `test/system/stimulus_tabs_test.rb` - Stimulus tabs tests
- `docs/testing-javascript-stimulus.md` - Testing documentation
- `docs/TESTING-SUMMARY.md` - This file

### Modified Files

- `config/ci.rb` - Added importmap integrity check (line 64-66)
- `test/test_helper.rb` - Improved OpenTelemetry disabling
- `test/application_system_test_case.rb` - Added `sign_in_as` helper (not fully working yet)

## Success Metrics

✅ **Importmap validation**: Catches missing JavaScript dependencies before deployment ✅ **System
tests**: Verify Stimulus controllers load and DOM structure is correct ✅ **CI integration**: All
checks run automatically on every commit ✅ **Documentation**: Clear guide for writing more
JavaScript tests

## Next Steps

1. ✅ Commit changes to feature branch
2. ✅ Run full CI suite locally
3. ✅ Create PR with clear description
4. ⏳ Get Dean's review
5. ⏳ Merge to main
