# Scheduled Scrape Lifecycle Validation Design

## Goal

Close the confidence gap around the freshness-first product loop with one automated
test that crosses the existing job, adapter, intake, match, event, and delivery seams.

## Scenario

An active Remax source returns one Pocitos rental through a stubbed `Net::HTTP`
response. A user has a matching, notification-enabled saved search and a Pushover
key. Running `RunScrapersJob` through the test queue must create the listing and seen
record, enqueue and perform `NotifyNewListingsJob`, create one notification event,
and invoke a fake Pushover client. Repeating the same scrape must update intake
freshness without another event or delivery.

## Idempotency Rule

Only listings first created by a scraping run retain that run as `scraping_run_id`.
Fan-out considers listings created by the current run, and the event additionally
has a unique listing/search idempotency key. A repeated provider item therefore
cannot notify twice.

## Non-goals

- Live provider or Pushover calls
- Running Solid Queue itself
- Changing schedules, retries, adapters, or notification behavior
