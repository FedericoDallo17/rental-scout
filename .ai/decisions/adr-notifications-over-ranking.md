# ADR: Prioritize Notifications Over Ranking

## Status
Accepted (2026-07-06)

## Context
The product brief promises both match scoring/ranking (Ticket 006) and notification
events (Ticket 012). Neither was built: the feed orders by `created_at DESC`, and no
code creates or delivers a `NotificationEvent` despite the table, model, and
`users.pushover_user_key` all existing. The 2026-07-06 audit found notifications are
the single largest gap between promise and reality — the product's core loop is
"tell me when a new matching apartment appears", and today it tells no one anything.

## Decision
Notifications are the next headline feature (Ticket 015). Ranking stays descoped and
Ticket 006 is deferred until at least a second real source exists — with one source,
one city, and zone/price/bedroom filters already applied, recency ordering is an
acceptable ranking proxy.

## Alternatives Considered
- Build ranking first: rejected — scoring a feed nobody is notified about adds no user
  value, and scoring signals are richer once multiple sources exist.
- Build both together: rejected — violates the small-ticket governance rule.

## Provisional Areas
- Delivery channel for the MVP (Pushover vs email) — decide inside Ticket 015; the
  schema supports either via `channel`.

## Consequences
- `notification_events` idempotency design from adr-scraper-domain finally gets used.
- Hourly scraping (Ticket 009) becomes worth validating end-to-end, since a scheduled
  run now has a user-visible effect.

## Related Tickets
- 015 (new), 012, 006 (deferred), 009
