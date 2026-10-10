# Inline tracking plan

1. Add bilingual clear-date submit actions.
2. Render Turbo Stream replacement with stable per-listing/per-track targets; keep submitted feed context.
3. Remove cards that no longer match collection filters and show empty-state copy.
4. Verify creation, clearing independent dates, context, ownership and inline validation with integration tests; run full suite and CSS mirror check.

Implemented. Full suite: 304 tests, 1837 assertions, passing. Initial local browser QA was blocked by denied local-origin permission. Production rollout and browser E2E completed on 2026-10-10 at image commit 858a93ad41976d859e0f7a6739460210650d91a2: clear each date independently, remove last card from Contacted filter with empty state, re-mark, edit dates and verify persistence after reload, create/remove favorite from feed. Logs confirmed create/update as TURBO_STREAM with HTTP 200, without redirect. Public /up HTTP 200. No migrations required; existing routing preserved. QA left one favorite with contact 2026-10-09, visit 2026-10-10 and no rejection.
