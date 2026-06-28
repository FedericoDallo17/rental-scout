# Headroom Policy

- Leave room for the human to decide on architecture, provider strategy, and rollout timing.
- Agents propose. The human decides.
- Prefer thin vertical slices over broad frameworks.
- Do not generalize the scraper pipeline before the mock/static adapter and hourly job prove the shape.
- Keep real provider integrations approval-gated.
- If idempotency, deduplication, or retry semantics are not explicit, stop and escalate.
