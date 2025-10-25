# Clearing Chrome HTTP Basic Auth Cache for Ops Panel

If Chrome is caching old credentials for the ops panel and you can't log in with new credentials,
here are several methods to clear them:

## Method 1: Clear Specific Site Credentials (Recommended)

1. Open Chrome and navigate to: `chrome://settings/passwords`
2. Search for your site URL (e.g., `techub.life`)
3. Find any entries for the ops panel URLs
4. Click the three dots and select "Remove"
5. Close and reopen Chrome
6. Visit the ops panel again - you should be prompted for credentials

## Method 2: Use Chrome DevTools

1. Open your site in Chrome
2. Press `F12` to open DevTools
3. Right-click the refresh button in the browser toolbar
4. Select "Empty Cache and Hard Reload"
5. Navigate to the ops panel - you should see the auth prompt

## Method 3: Clear All Auth Credentials

1. Open Chrome Settings: `chrome://settings/`
2. Go to "Privacy and security" → "Clear browsing data"
3. Select "Advanced" tab
4. Check only "Passwords and other sign-in data"
5. Time range: "All time"
6. Click "Clear data"
7. Restart Chrome

## Method 4: Use Incognito/Private Window

As you discovered, this works immediately:

1. Open a new Incognito window (`Ctrl+Shift+N` or `Cmd+Shift+N`)
2. Navigate to your ops panel
3. Enter the new credentials
4. This won't affect your regular browser session

## Method 5: Logout URL (Force Chrome to Forget)

Visit this URL format to force Chrome to prompt for new credentials:

```
https://logout@techub.life/ops
```

Or with dummy credentials:

```
https://wrong:credentials@techub.life/ops
```

Chrome will fail to authenticate and then prompt you for new credentials.

## Method 6: Clear Site-Specific Data

1. Click the lock icon (or "Site settings") in the address bar
2. Click "Site settings"
3. Scroll down and click "Clear data"
4. Confirm
5. Reload the page

## Method 7: Command Line (macOS/Linux)

Close Chrome completely, then run:

```bash
# macOS
rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Login\ Data*

# Linux
rm -rf ~/.config/google-chrome/Default/Login\ Data*
```

Then restart Chrome.

## Prevention

To avoid this issue in the future:

1. Use Incognito mode for testing different credentials
2. Document credential changes in a secure location
3. Use a password manager that can update credentials easily
4. Test new credentials in Incognito before updating production

## Production Credential Updates

When updating production ops credentials:

1. Update credentials in Rails encrypted credentials:

   ```bash
   EDITOR="cursor --wait" bin/rails credentials:edit
   ```

2. Update the `mission_control.jobs.http_basic` value:

   ```yaml
   mission_control:
     jobs:
       http_basic: 'username:newpassword'
   ```

3. Deploy the change:

   ```bash
   bin/kamal deploy
   ```

4. Clear your browser cache using one of the methods above
5. Verify access in Incognito mode first

## Troubleshooting

If you still can't access after trying these methods:

1. Check that credentials are correct in the Rails app:

   ```bash
   bin/kamal app exec "bin/rails runner \"puts Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)\""
   ```

2. Check Rails logs for authentication attempts:

   ```bash
   bin/kamal app logs | grep "HTTP Basic"
   ```

3. Try a different browser (Firefox, Safari) to rule out Chrome-specific issues
