# Grouped Run Notifications Design

The existing pipeline emits one push for every new-listing/search match. Overlapping
searches can therefore notify one user repeatedly about the same run and listing.

Ticket 023 retains `NotificationEvent` as the persisted match and idempotency record,
but groups newly created events by search owner at delivery time. Each user receives
one summary containing the distinct listing count and a link to the authenticated
scraping-run results page. That page queries persisted events through the current
user's searches, so it preserves what matched at notification time and cannot expose
another user's matches.

No schema change is required. Missing keys and delivery failures update every event
in the attempted user batch consistently.
