# Inline tracking plan

1. Add bilingual clear-date submit actions.
2. Render Turbo Stream replacement with stable per-listing/per-track targets; keep submitted feed context.
3. Remove cards that no longer match collection filters and show empty-state copy.
4. Verify creation, clearing independent dates, context, ownership and inline validation with integration tests; run full suite and CSS mirror check.

Implemented. Full suite: 304 tests, 1837 assertions, passing. Browser QA blocked by denied local-origin permission, without workaround. Production rollout pending.
