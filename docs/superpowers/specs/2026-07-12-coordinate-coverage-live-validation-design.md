# Coordinate Coverage and Live Validation Design

The runs workbench reports coordinate coverage per listing source so missing geometry
work is prioritized from measured inventory rather than intuition. Each provider is
then validated with a single read-only first-page request. Validation must not call
intake, create scraping runs, enqueue jobs, or send notifications.

The report captures normalized result count, distinct neighborhood labels, coordinate
coverage, malformed result count, and a small canonical-URL resolution sample. Provider
requests remain bounded to one page and use the adapters' existing timeouts.
