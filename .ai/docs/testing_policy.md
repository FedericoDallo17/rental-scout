# Testing Policy

- No feature is done without tests or an explicit documented reason.
- Model/domain logic needs unit/model tests.
- Background jobs need job tests.
- Source adapters should use fixture-driven tests when practical.
- Idempotency and duplicate prevention should be covered explicitly.
- Portal-facing flows should cover the primary listing review path when behavior changes.
- Mock/static adapters should avoid real HTTP scraping in tests.
