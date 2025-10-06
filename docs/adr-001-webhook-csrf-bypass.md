# ADR-001: GitHub Webhook CSRF Protection Bypass

## Status

Accepted

## Context

GitHub webhooks require server-to-server communication without browser sessions. Rails CSRF
protection is designed for browser-based requests and conflicts with webhook authentication
patterns.

## Decision

Disable CSRF protection for GitHub webhook endpoints using
`skip_before_action :verify_authenticity_token` with HMAC signature verification as the primary
authentication mechanism.

## Implementation Details

### Controller Configuration

```ruby
module Github
  class WebhooksController < ApplicationController
    # @codeql-disable-next-line csrf-protection-disabled
    skip_before_action :verify_authenticity_token

    def receive
      # HMAC signature verification
      # Webhook processing
    end
  end
end
```

### Security Measures

- HMAC signature verification using `X-Hub-Signature-256` header
- Secure comparison using `ActiveSupport::SecurityUtils.secure_compare`
- Shared secret validation via `GITHUB_WEBHOOK_SECRET`
- Request rejection on signature mismatch

## Alternatives Considered

### Option 1: ActionController::API

```ruby
class WebhooksController < ActionController::API
  # No CSRF protection by default
end
```

**Rejected**: Requires architectural changes, loses web controller features

### Option 2: Separate API Namespace

```ruby
module Api
  module Github
    class WebhooksController < ActionController::API
    end
  end
end
```

**Rejected**: Adds complexity without security benefits

### Option 3: Custom CSRF Token System

**Rejected**: Overly complex, HMAC signatures are more secure

## Consequences

### Positive

- Industry standard approach for webhook handling
- HMAC signatures provide stronger authentication than CSRF tokens
- Minimal code complexity
- Clear separation of concerns

### Negative

- CodeQL security scanner flags (suppressed with documentation)
- Requires understanding of webhook security patterns
- Potential confusion for developers unfamiliar with webhooks

## Security Analysis

### CSRF Protection Purpose

- Prevents malicious sites from making requests on behalf of logged-in users
- Uses tokens embedded in HTML forms
- Validates requests originate from your domain

### Webhook Security Model

- Server-to-server communication (no browser involved)
- HMAC signatures provide cryptographic authentication
- Shared secret ensures only GitHub can generate valid signatures
- No user sessions or cookies involved

### Risk Assessment

- **Low Risk**: HMAC verification is cryptographically secure
- **Industry Standard**: Used by GitHub, Stripe, and other major platforms
- **Well Documented**: Rails guides recommend this pattern

## References

- [Rails Security Guide - CSRF Protection](https://guides.rubyonrails.org/security.html#cross-site-request-forgery-csrf)
- [GitHub Webhook Security](https://docs.github.com/en/developers/webhooks-and-events/webhooks/securing-your-webhooks)
- [ActionController::API Documentation](https://api.rubyonrails.org/classes/ActionController/API.html)

## Review Date

2025-01-08

## Decision Makers

- Development Team
- Security Review

## Related ADRs

None

## Implementation Status

✅ Implemented in `app/controllers/github/webhooks_controller.rb` ✅ CodeQL suppression added ✅
Security verification service implemented
