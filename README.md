# Timbre

Timbre is a Rails 8 property search app for finding new Montevideo rentals and homes for sale before they disappear into separate property sites. It brings listings from four sources into one feed, matches them against saved searches, and alerts users to new matches.

**[Try the interactive tour](https://homes.dallo.dev/tour)** — a five-step English/Spanish walkthrough with fictional listings. It needs no account and does not run scrapers, access live inventory, save changes, or send notifications.

## What it does

- **Finds fresh properties:** Solid Queue runs hourly acquisition for rentals and sales from InfoCasas, Remax, Imperium, and Housi. A weekly reconciliation checks older inventory; daily jobs clean up stale listings and backfill missing coordinates.
- **Builds a shared feed:** Source adapters normalize listings; intake handles source-local and cross-source duplicates before storing them in PostgreSQL/PostGIS.
- **Matches private searches:** Users can save neighborhood zones and price, currency, bedroom, and area preferences. PostGIS zone checks and deterministic scoring explain why a listing matches.
- **Tracks apartments:** Favorites and contact, visit, or rejection notes stay private to each user, including when old inventory is removed.
- **Sends new-match alerts:** Grouped browser Web Push and optional Pushover delivery use persisted keys to avoid duplicate notifications.
- **Shows operational health:** Run history, per-source results, request counts, and location-quality metrics make ingestion problems visible.

The interface supports English and Spanish. The live app uses separate Rails web and Solid Queue job containers, deployed with Docker and Kamal to a Hetzner server. PostgreSQL/PostGIS, HTTPS, and backup tooling are part of that deployment.

## Why I built it

I first used a small notification-only scraper for my own apartment search. When a friend needed the same thing, I rebuilt it as this Rails product with persistent searches, a dashboard, matching, alerts, and operational tools. It is designed for that small real-world need rather than user acquisition.

## Run locally

The project uses the Ruby version in `.ruby-version` and PostgreSQL with PostGIS.

```sh
bin/setup
bin/rails server
```

Run `bin/jobs` in a second terminal for scheduled and background work. The test suite is `bin/rails test`. Local seeds provide example data; the public tour is also available without setup.

## Brand identity

Timbre uses the approved round door wordmark, Patio green/ivory identity, yellow
interface accents and locally hosted Manrope Variable (SIL OFL 1.1). Production
assets and the [brand guide](public/branding/guia-de-marca.md) live in
`public/branding/`; install metadata lives in `public/manifest.json`.
The authentication logo plays once per tab with an explicit replay control.
Reduced motion and JavaScript-free access show the static final mark.
Spanish navigation uses **Búsquedas**, **Timbres** (personal match history) and
**Avisos** (delivery settings). Internal application and infrastructure names
remain stable so the visual rename does not invalidate sessions or push keys.

## Development process

The project also exercises an AI-assisted development workflow. Planning, review, decisions, and status notes live in [`.ai/`](.ai/); the [workflow guide](.ai/WORKFLOW.md) explains the loop. The application and its production behavior are the primary artifact; the workflow is a separate experiment documented alongside it.

## Future work

- Revisit an interactive zone map for the search form.
