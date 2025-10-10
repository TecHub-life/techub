# Roadmap

## Completed ✅

- **GitHub Integration Module**: Complete GitHub App authentication, OAuth flows, webhook handling
- **Profile Data Collection**: Comprehensive GitHub profile data gathering (repos, languages,
  activity, README)
- **Multi-User Support**: Dynamic profile access for any GitHub username
- **Data Storage**: Structured database schema with JSON columns and related tables
- **Local Development**: Rails 8 + SQLite + Solid Queue + Kamal deployment ready
- **Gemini Provider Parity**: Text, vision, and image gen via AI Studio and Vertex with verify tasks
- **Robustness**: Lenient JSON parsing, truncation retries, and stable CI across branches
- **CI Hygiene**: Single-run per change (push main, PR on branches) with concurrency cancellation

## Now (Phase 1: AI Foundation)

- Implement the free submission funnel with GitHub eligibility scoring and decline messaging
- Configure object storage (S3/GCS) for generated card images and assets
- Design AI prompts for trading card stats generation (attack/defense, buffs, weaknesses)
- Create Gemini client service with proper error handling and rate limiting
- Add profile-backed prompt fallback when avatar description is weak/partial
- Telemetry for provider, attempts, fallback_used, and finish_reason in metadata

## Next (Phase 2: AI Profile Processing)

- Build AI profile analysis service to transform GitHub data into trading card stats
- Implement card image generation using Gemini Flash 2.5
- Create trading card data structure and templates
- Test AI generation pipeline with existing profile data (loftwah, dhh, matz, torvalds)
- Add ImageMagick-based post-processing to optimise generated images (size, format, metadata)

## Soon (Phase 3: Card Presentation)

- Build trading card rendering system (HTML/CSS templates)
- Implement card export functionality (images, PDFs)
- Create card directory with search and filtering
- Add card sharing and embedding features

## Later (Phase 4: Production Features)

- Build eligibility override tooling (manual approvals, appeal notes, audit history)
- Implement notification emails (Resend) for card completion
- Build admin dashboard for card curation and analytics
- Add API endpoints for programmatic card access
- Create physical card printing pipeline for limited edition decks

## Future (Phase 5: Advanced Features)

- PR backfill: split oversized profile orchestration into smaller services and add direct tests for
  remaining GitHub helpers so every ServiceResult has a matching spec
- Leaderboards and trending cards
- Card trading and collection features
- Advanced analytics and insights
- Partner integrations and API marketplace
- Mobile app for card collection and sharing
