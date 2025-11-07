# JavaScript & Stimulus Testing Infrastructure

## Overview

This document describes TecHub's testing infrastructure for JavaScript, Stimulus controllers, and
importmap integrity. These tests ensure that frontend functionality works correctly and that missing
importmap pins are caught before deployment.

## Problem Statement

Previously, our test suite never loaded the real browser importmap, so missing pins wouldn't surface
until runtime in production. We also lacked any JS/system tests that exercised Stimulus behavior,
meaning controller boot failures could go undetected.

## Solution

We've implemented two complementary approaches:

### 1. Capybara System Tests (JS-enabled)

**File:** `test/system/stimulus_tabs_test.rb`

These tests run in a real browser (headless Chrome) with JavaScript enabled, exercising actual
Stimulus behavior.

#### What it tests:

- **Profile page tab switching** - Verifies the tabs controller loads and switches between Profile,
  Cards, and Overview tabs
- **Ops profile page tab switching** - Ensures tabs work in the ops interface
- **Graceful degradation** - Documents expected behavior when Stimulus fails to load

#### Key features:

- Uses Capybara with Selenium WebDriver (headless Chrome)
- Waits for Stimulus controllers to initialize (`data-controller='tabs'`)
- Verifies ARIA attributes are properly managed by Stimulus
- Checks that tab panels show/hide correctly
- Catches importmap boot failures that would break tab functionality

#### Running the tests:

```bash
# Run all system tests
bin/rails test:system

# Run just the Stimulus tests
bin/rails test test/system/stimulus_tabs_test.rb

# Run with visible browser (for debugging)
HEADLESS=false bin/rails test:system
```

### 2. Importmap Integrity Check

**File:** `bin/check-importmap`

This script validates that all JavaScript imports are properly configured before tests run.

#### What it checks:

1. **Application.js imports are pinned** - Every import in `app/javascript/application.js` must have
   a corresponding pin in `config/importmap.rb`

2. **No unresolved/relative imports** - Flags suspicious imports that start with `./` or `../` or
   are bare names without extensions

3. **All Stimulus controllers are accessible** - Verifies every `*_controller.js` file is accessible
   via the importmap (through `pin_all_from`)

4. **Critical dependencies present** - Ensures `@hotwired/turbo-rails`, `@hotwired/stimulus`, and
   `@hotwired/stimulus-loading` are pinned

5. **Custom modules are pinned** - Verifies `techub_console` and other custom modules are properly
   configured

#### Running the check:

```bash
# Run directly
ruby bin/check-importmap

# Or via CI script
bin/ci
```

#### Example output:

```
📦 Checking imports from application.js...
✅ Import '@hotwired/turbo-rails' is pinned
✅ Import 'controllers' is pinned
✅ Import 'techub_console' is pinned

🔍 Checking for unresolved or relative top-level imports...
✅ No suspicious relative or unresolved imports found

🎮 Checking Stimulus controllers...
✅ All 15 Stimulus controllers are accessible

🔧 Checking critical dependencies...
✅ Critical dependency '@hotwired/turbo-rails' is present
✅ Critical dependency '@hotwired/stimulus' is present
✅ Critical dependency '@hotwired/stimulus-loading' is present

🎯 Checking custom modules...
✅ Custom module 'techub_console' is pinned and file exists

✨ Importmap validation passed! All imports are properly configured.
```

## CI Integration

Both checks are integrated into the CI pipeline (`config/ci.rb`):

1. **Importmap check** runs early (after npm install, before db:prepare)
2. **System tests** run after unit tests

This ensures:

- Missing pins are caught before any tests run
- Stimulus functionality is verified in a real browser
- Breaking changes to importmap or controllers fail CI immediately

## When to Update

### Add a new Stimulus controller:

1. Create `app/javascript/controllers/my_controller.js`
2. The importmap check will automatically verify it's accessible (via `pin_all_from`)
3. Consider adding a system test if it has critical user-facing behavior

### Add a new top-level JavaScript module:

1. Create `app/javascript/my_module.js`
2. Add `pin "my_module"` to `config/importmap.rb`
3. Import it in `application.js`: `import 'my_module'`
4. The importmap check will verify the pin exists

### Modify tab behavior:

1. Update `app/javascript/controllers/tabs_controller.js`
2. Run system tests to ensure changes don't break existing functionality
3. Add new test cases if adding new tab-related features

## Debugging Tips

### System test fails with "element not found":

- Check if Stimulus controller is initializing: `assert_selector "[data-controller='tabs']"`
- Increase wait times if needed: `assert_selector "...", wait: 5`
- Run with visible browser: `HEADLESS=false bin/rails test:system`

### Chrome/Chromedriver missing locally

1. Download browser & driver the same way CI does:
   ```bash
   npx @puppeteer/browsers install chrome@stable
   npx @puppeteer/browsers install chromedriver@stable
   ```
   Puppeteer nests the driver under the browser folder; note both paths from the CLI output.
2. Export them in your shell (e.g. `~/.zshrc`):
   ```bash
   export SELENIUM_CHROME_BINARY="$HOME/gits/techub/chrome/linux-142.0.7444.61/chrome-linux64/chrome"
   export CHROMEDRIVER_PATH="$HOME/gits/techub/chrome/linux-142.0.7444.61/chrome-linux64/chromedriver/linux-142.0.7444.61/chromedriver-linux64/chromedriver"
   export WEBDRIVER_CHROME_DRIVER="$CHROMEDRIVER_PATH"
   export PATH="$PATH:$(dirname "$CHROMEDRIVER_PATH")"
   ```
   Adjust the versioned folder if Puppeteer installs a newer build.
3. Reload your shell (`source ~/.zshrc`) and verify:
   ```bash
   "$SELENIUM_CHROME_BINARY" --version
   chromedriver --version
   ```
   Once both commands work, rerun `bin/rails test:system …`.

### Importmap check fails:

- Run `bin/importmap json` to see the full importmap
- Check `config/importmap.rb` for missing pins
- Verify file paths match import names
- Ensure `pin_all_from` patterns cover all controllers

### Tabs not switching in browser:

1. Open browser console (F12)
2. Check for JavaScript errors
3. Verify Stimulus is loaded: `window.Stimulus`
4. Check controller registration: `window.Stimulus.controllers`

## Architecture Decisions

### Why Capybara + Selenium?

- Rails 8 default for system tests
- Runs real JavaScript in real browser
- Catches issues that unit tests miss
- Headless mode is fast enough for CI

### Why not just rely on importmap check?

- Importmap check validates configuration
- System tests validate runtime behavior
- Both are needed for complete coverage

### Why run system tests in CI?

- Catches Stimulus boot failures
- Verifies tab switching works end-to-end
- Prevents shipping broken JavaScript
- Adds ~10-20 seconds to CI time (acceptable tradeoff)

## Future Enhancements

Consider adding:

- System tests for other Stimulus controllers (lightbox, autocomplete, etc.)
- Visual regression tests for card rendering
- Performance benchmarks for tab switching
- E2E tests for complete user flows

## Related Files

- `test/system/stimulus_tabs_test.rb` - System tests
- `bin/check-importmap` - Importmap validation script
- `config/ci.rb` - CI pipeline configuration
- `config/importmap.rb` - Importmap configuration
- `app/javascript/application.js` - Main JS entry point
- `app/javascript/controllers/tabs_controller.js` - Tabs Stimulus controller
- `test/application_system_test_case.rb` - System test base class
