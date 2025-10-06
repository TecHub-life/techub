# Roadmap

## Completed ✅

- **GitHub Integration Module**: Complete GitHub App authentication, OAuth flows, webhook handling
- **Profile Data Collection**: Comprehensive GitHub profile data gathering (repos, languages,
  activity, README)
- **Multi-User Support**: Dynamic profile access for any GitHub username
- **Data Storage**: Structured database schema with JSON columns and related tables
- **Local Development**: Rails 8 + SQLite + Solid Queue + Kamal deployment ready

## Now (Phase 1: AI Foundation)

- Set up Google Gemini integration with Flash 2.5 model for image generation
- Configure object storage (S3/GCS) for generated card images and assets
- Design AI prompts for trading card stats generation (attack/defense, buffs, weaknesses)
- Create Gemini client service with proper error handling and rate limiting

## Next (Phase 2: AI Profile Processing)

- Build AI profile analysis service to transform GitHub data into trading card stats
- Implement card image generation using Gemini Flash 2.5
- Create trading card data structure and templates
- Test AI generation pipeline with existing profile data (loftwah, dhh, matz, torvalds)

## Soon (Phase 3: Card Presentation)

- Build trading card rendering system (HTML/CSS templates)
- Implement card export functionality (images, PDFs)
- Create card directory with search and filtering
- Add card sharing and embedding features

## Later (Phase 4: Production Features)

- **Integrate Stripe Checkout for $3.50 card generation requests** (core requirement)
- Implement notification emails (Resend) for card completion
- Build admin dashboard for card curation and analytics
- Add API endpoints for programmatic card access
- Create physical card printing pipeline for limited edition decks

## Future (Phase 5: Advanced Features)

- Leaderboards and trending cards
- Card trading and collection features
- Advanced analytics and insights
- Partner integrations and API marketplace
- Mobile app for card collection and sharing
