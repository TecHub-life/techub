# Architectural Decision Records (ADR) Index

This directory contains Architectural Decision Records (ADRs) documenting important technical
decisions made in the TechHub project.

## What are ADRs?

ADRs are documents that capture important architectural decisions, the context that led to them, and
their consequences. They help maintain institutional knowledge and provide rationale for future
developers.

## ADR List

### [ADR-001: GitHub Webhook CSRF Protection Bypass](./adr-001-webhook-csrf-bypass.md)

**Status**: Accepted  
**Date**: 2025-01-08  
**Summary**: Decision to disable CSRF protection for GitHub webhook endpoints using HMAC signature
verification instead.

### [ADR-0001: LLM cost control via eligibility gate and profile fallback](./adr/0001-llm-cost-control-eligibility-gate.md)

**Status**: Accepted  
**Date**: 2025-10-10  
**Summary**: Require a minimum-quality profile before running Gemini; if eligible, attempt LLM and
fallback to profile context on failures.

### [ADR-0002: Screenshot generation driver — Node Puppeteer](./adr/0002-screenshots-driver-puppeteer-node.md)

**Status**: Accepted  
**Date**: 2025-10-11  
**Summary**: Standardize on Node Puppeteer for rendering and capturing OG/card images; tests bypass
browser; containers use system Chromium.

### [ADR-0003: Submit page manual inputs for scrape URL and repositories](./adr/0003-submit-manual-inputs.md)

**Status**: Proposed  
**Date**: 2025-10-12  
**Summary**: Accept a personal URL and up to 4 GitHub repositories during submission; persist
`submitted` repositories and a scrape URL; preserve them across sync and ingest them in the
orchestration pipeline.

### [ADR-0004: Scraping driver — Puppeteer vs. Nokogiri](./adr/0004-scraping-driver.md)

**Status**: Proposed  
**Date**: 2025-10-12  
**Summary**: Use Ruby `Net::HTTP` + `Nokogiri` for submission URL scraping with SSRF protections,
caps, and timeouts; consider Puppeteer fallback only if needed.

## ADR Template

When creating new ADRs, use this template:

```markdown
# ADR-XXX: [Title]

## Status

[Proposed | Accepted | Rejected | Superseded]

## Context

[Describe the context and problem statement]

## Decision

[Describe the decision and rationale]

## Consequences

[Describe the positive and negative consequences]

## References

[Links to relevant documentation, examples, etc.]

## Review Date

[Date when this ADR should be reviewed]

## Decision Makers

[List of people involved in the decision]

## Related ADRs

[Links to related ADRs]

## Implementation Status

[Current implementation status]
```

## Guidelines

1. **One Decision Per ADR**: Each ADR should focus on a single architectural decision
2. **Clear Status**: Always include the current status
3. **Context First**: Explain the problem before the solution
4. **Consequences**: Document both positive and negative outcomes
5. **Review Dates**: Set review dates for decisions that may need updates
6. **Implementation Status**: Track whether decisions have been implemented

## When to Create an ADR

Create an ADR when making decisions that:

- Affect multiple parts of the system
- Have security implications
- Involve trade-offs between different approaches
- Set patterns for future development
- Have long-term consequences

## Review Process

1. **Proposed**: Initial draft for discussion
2. **Accepted**: Decision approved and ready for implementation
3. **Rejected**: Decision not approved
4. **Superseded**: Replaced by a newer ADR

## Maintenance

- Review ADRs periodically for accuracy
- Update implementation status as changes are made
- Archive outdated ADRs rather than deleting them
- Link related ADRs together
