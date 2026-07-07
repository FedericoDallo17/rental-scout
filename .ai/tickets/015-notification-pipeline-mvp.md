# Ticket: 015 - Notification Pipeline MVP

## Goal
Make the product's core promise real: after each scrape run, create and deliver
`NotificationEvent`s for new listings matching each user's active search.

## Acceptance Criteria
- A producer runs after each scraping run and creates events idempotently
  (unique `idempotency_key` per user/listing/search).
- One delivery channel works end-to-end (Pushover via `users.pushover_user_key`, or
  email — decide in spec; mailer defaults must be fixed if email).
- Delivery failures are recorded on the event (`status`, `delivery_error`), never raised
  into the scrape run.
- An hourly scheduled run demonstrably produces a notification (end-to-end validation
  of Ticket 009's recurring job).

## Human Approval Required?
Yes (delivery channel choice and any external service credentials)
