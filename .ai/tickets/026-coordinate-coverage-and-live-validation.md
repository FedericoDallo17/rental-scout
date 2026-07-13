# Ticket: 026 - Coordinate Coverage and Live Validation

## Goal

Measure coordinate coverage by source and validate city-wide provider queries with
small read-only probes before choosing new coordinate extraction work.

## Acceptance Criteria

- [x] Runs observability shows total, spatial, fallback, unresolved, and coverage by source.
- [x] One first-page read-only probe is performed for each real provider.
- [x] Probes do not persist listings, enqueue jobs, or send notifications.
- [x] Findings record result counts, neighborhood diversity, coordinate coverage, URL validity, and parsing failures.
- [x] InfoCasas detail backfill is selected and scheduled conservatively at 20 listings per day.

## Human Approval Required?

Yes. The user explicitly approved conservative live provider validation on 2026-07-12.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] No ADR required; existing provider and PostGIS boundaries remain unchanged
- [x] Spec/plan committed alongside the work (`docs/superpowers/`)
- [x] Superseded Pocitos-only assumptions were removed in Ticket 025
