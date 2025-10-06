# TecHub Setup Guide

This guide will walk you through setting up TecHub locally from scratch, including all required
external services and credentials.

## What is TecHub?

TecHub is an AI-powered collectible trading card system for GitHub developer profiles. It creates
stylized trading cards based on GitHub profile data, repositories, contributions, and activity.
Users can submit GitHub usernames for $3.50 to generate their trading card.

## Prerequisites

- Ruby 3.2+ (check with `ruby --version`)
- Node.js 18+ (check with `node --version`)
- Git
- A GitHub account
- A RESEND account for email services

## Step 1: Clone and Install Dependencies

```bash
# Clone the repository
git clone https://github.com/your-username/techub.git
cd techub

# Install Ruby dependencies
bundle install

# Install Node.js dependencies
npm install

# Set up the database and prepare the application
bin/setup --skip-server
```

## Step 2: Set Up GitHub App

TecHub requires a GitHub App to access GitHub's API. Follow these steps:

### 2.1 Create a GitHub App

1. Go to [GitHub App Settings](https://github.com/settings/apps/new)
2. Fill in the following details:

**Basic Information:**

- **GitHub App name**: `TecHub-local` (or your preferred name)
- **Description**: `AI-powered collectible trading cards for GitHub developer profiles`
- **Homepage URL**: `http://localhost:3000` (for development)

**Webhook Configuration:**

- **Webhook URL**: `http://localhost:3000/github/webhooks/receive` (for development)
- **Webhook Secret**: Generate a random secret (save this for later)

**Permissions & Events:**

- **Repository permissions**:
  - Contents: Read
  - Metadata: Read
  - Pull requests: Read
- **Account permissions**:
  - Email addresses: Read
  - Followers: Read
  - Following: Read
  - Profile: Read
- **Subscribe to events**:
  - Workflow runs (optional, for future webhook features)

**Where can this GitHub App be installed?**

- Select "Any account"

### 2.2 Get Your App Credentials

After creating the app, you'll need to collect these values:

1. **App ID**: Found on the app's main page
2. **Client ID**: Found in the "OAuth Apps" section
3. **Client Secret**: Click "Generate a new client secret"
4. **Private Key**: Go to "Private keys" → "Generate a private key" → Download the `.pem` file

### 2.3 Install the App

1. Go to your GitHub App's "Install App" page
2. Click "Install" on your personal account
3. Note the **Installation ID** from the URL:
   `https://github.com/settings/installations/<INSTALLATION_ID>`

## Step 3: Set Up RESEND Email Service

TecHub uses RESEND for email notifications:

1. Go to [RESEND](https://resend.com) and create an account
2. Navigate to [API Keys](https://resend.com/api-keys)
3. Create a new API key
4. Copy the API key (starts with `re_`)

## Step 4: Configure Environment Variables

### 4.1 Create Environment File

```bash
# Copy the example environment file
cp .env.example .env
```

### 4.2 Fill in Your Values

Edit `.env` with your actual values:

```bash
# GitHub App Configuration
GITHUB_APP_ID=123456
GITHUB_CLIENT_ID=your_oauth_client_id
GITHUB_CLIENT_SECRET=your_oauth_client_secret
GITHUB_INSTALLATION_ID=123456
GITHUB_WEBHOOK_SECRET=your_webhook_secret_here

# GitHub Private Key (choose one method)
# Method 1: Paste the full key content
GITHUB_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
your_private_key_content_here
-----END RSA PRIVATE KEY-----"

# Method 2: Use file path (alternative)
# GITHUB_PRIVATE_KEY_PATH=path/to/your/private-key.pem

# OAuth Callback URLs
GITHUB_CALLBACK_URL_DEV=http://localhost:3000/auth/github/callback
GITHUB_CALLBACK_URL_PROD=https://your-domain.com/auth/github/callback

# RESEND Email Service
RESEND_API_KEY=re_your_resend_api_key_here
```

### 4.3 Alternative: Use Rails Credentials (Recommended for Production)

For better security, you can store secrets in Rails encrypted credentials:

```bash
# Edit Rails credentials
EDITOR="code --wait" bin/rails credentials:edit
```

Add this structure:

```yaml
github:
  app_id: 123456
  client_id: your_oauth_client_id
  client_secret: your_oauth_client_secret
  private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    your_private_key_content_here
    -----END RSA PRIVATE KEY-----
  installation_id: 123456
  webhook_secret: your_webhook_secret_here

resend:
  api_key: re_your_resend_api_key_here

active_record_encryption:
  primary_key: <%= `openssl rand -hex 32`.strip %>
  deterministic_key: <%= `openssl rand -hex 32`.strip %>
  key_derivation_salt: <%= `openssl rand -hex 32`.strip %>
```

## Step 5: Start the Application

```bash
# Start the full development stack
bin/dev
```

This will start:

- Rails server on port 3000
- CSS watcher for Tailwind
- Solid Queue workers for background jobs
- Recurring scheduler

## Step 6: Verify Setup

### 6.1 Run Tests

```bash
# Run the full test suite
bin/ci
```

### 6.2 Test GitHub Integration

1. Visit `http://localhost:3000`
2. Try accessing a GitHub profile (e.g., `http://localhost:3000/loftwah`)
3. Check the Rails logs for any GitHub API errors

### 6.3 Test OAuth Flow

1. Visit `http://localhost:3000/auth/github`
2. Complete the OAuth flow
3. Verify you're redirected back to the application

## Step 7: Understanding the Application

### 7.1 Key Features

- **Profile Cards**: AI-generated trading cards for GitHub profiles
- **Directory**: Searchable collection of profiles
- **API**: JSON endpoints for programmatic access
- **OAuth**: GitHub authentication for users
- **Webhooks**: GitHub webhook handling (currently handles workflow runs)

### 7.2 Database Schema

The application uses SQLite with these main tables:

- `profiles`: GitHub profile data
- `users`: Authenticated users
- `profile_repositories`: Repository information
- `profile_languages`: Language statistics
- `profile_organizations`: Organization memberships
- `profile_readmes`: Profile README content

### 7.3 GitHub API Usage

Per profile sync, the app makes 11-16 API calls:

- User profile data
- Repository information
- Profile README
- Recent activity
- Organizations
- Pinned repositories (GraphQL)
- Social accounts (GraphQL)

## Troubleshooting

### Common Issues

1. **GitHub API Rate Limits**: The app uses GitHub App authentication which has higher rate limits
2. **Private Key Format**: Ensure your private key includes the full PEM format with headers
3. **OAuth Redirect**: Make sure your callback URL matches exactly what's configured in GitHub
4. **Database Issues**: Run `bin/rails db:reset` if you encounter database errors

### Debug Commands

```bash
# Check GitHub configuration
bin/rails runner "puts Github::Configuration.app_id"

# Test GitHub API connection
bin/rails runner "puts Github::AppClientService.call"

# Refresh a specific profile
bin/rails 'profiles:refresh[username]'

# View all stored profiles
sqlite3 storage/development.sqlite3 "SELECT login, name, last_synced_at FROM profiles;"
```

### Logs

Check the Rails logs for detailed error messages:

```bash
tail -f log/development.log
```

## Production Deployment

For production deployment, see the Kamal configuration in `config/deploy.yml`. You'll need:

1. A server with Docker
2. Domain name with SSL
3. Updated GitHub App settings for production URLs
4. Environment variables configured on the server

## Support

If you encounter issues:

1. Check the Rails logs for error messages
2. Verify all environment variables are set correctly
3. Test GitHub API connectivity
4. Ensure your GitHub App has the correct permissions

## Security Notes

- Never commit `.env` files or private keys to version control
- Use Rails credentials for production secrets
- Rotate GitHub App secrets regularly
- Monitor API usage and rate limits
- Keep dependencies updated

---

Created by **Jared Hooker ([@GameDevJared89](https://x.com/GameDevJared89))** and **Dean Lofts
([@loftwah](https://x.com/loftwah))**.
