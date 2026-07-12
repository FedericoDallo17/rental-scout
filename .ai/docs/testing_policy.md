# Testing Policy

- No feature is done without tests or an explicit documented reason.
- Model/domain logic needs unit/model tests.
- Background jobs need job tests.
- Source adapters must be tested by stubbing at the HTTP layer (WebMock/fixture
  responses), never by stubbing `fetch_listings` wholesale — wholesale stubs once
  hid a functionally dead coordinate backfill behind a green suite.
- Idempotency and duplicate prevention should be covered explicitly.
- Portal-facing flows should cover the primary listing review path when behavior changes.
- Mock/static adapters should avoid real HTTP scraping in tests.
