# ADR: Turbo Streams for scrape progress

## Status
Accepted

## Context
Scraping runs execute in a Solid Queue worker separate from the Rails web process. The admin progress page originally refreshed the whole document periodically, while in-process Action Cable delivery could not carry worker updates to the browser.

## Decision
Use Turbo Streams over Action Cable for persisted scrape progress. Development uses Action Cable's PostgreSQL adapter for cross-process delivery; production uses the existing Solid Cable database. Scraping run and source-run commits replace one operational partial. Propshaft and import maps provide the supported Rails JavaScript path. A 30-second document refresh remains as a connection-loss fallback.

## Alternatives Considered
- Server-Sent Events: focused but holds a web request and creates a second live-update architecture.
- Short-interval polling: simple but repeatedly renders and transfers the full page.
- In-process async Cable: cannot communicate between `bin/jobs` and `rails server`.

## Provisional Areas
- The 30-second fallback interval can be tuned after observing real deployments.
- Broadcast frequency may be debounced if provider request volume becomes high.

## Consequences
- Run progress is delivered as persisted state changes without a full-page refresh.
- Web and worker processes need access to the configured Cable backend.
- JavaScript assets are now served through Propshaft/import maps.

## Related Tickets
- Ticket 036 inventory-health observability
