# Quality Standards

- Prefer the smallest correct change.
- Keep one ticket focused on one outcome.
- Match the existing Rails app structure before adding abstractions.
- Do not over-automate the workflow.
- Early slices may use a mock/static source adapter.
- Real provider integrations should stay isolated per adapter.
- Reviews should check correctness, simplicity, N+1 risk, and scraper/job safety.
- Portal changes should keep listing score, source metadata, and review flow clear.
- Backend changes should state deduplication and notification idempotency behavior explicitly.
