# Ticket: 018 - MercadoLibre Source

## Goal
Add MercadoLibre Uruguay as the second real rental listing source for the freshness-first marketplace feed.

## Acceptance Criteria
- MercadoLibre index payload shape is captured from a bounded request before adapter normalization code is finalized.
- `Sources::MercadoLibreApiAdapter` emits normalized listing hashes accepted by `Scraping::ListingIntake`.
- MercadoLibre listings include explicit `currency` values from the provider; no implicit UYU conversion is performed.
- Price filtering does not compare listings across currencies as if they shared one currency.
- Cross-source deduplication behavior is documented explicitly; this ticket keeps source-local dedup unless a reliable provider-backed shared identifier is found.
- Tests cover adapter normalization, pagination/request bounds, currency behavior, and intake contract compatibility.
- `db/seeds.rb` creates a `ListingSource` with `adapter_key: "mercado_libre_api"`.

## Human Approval Required?
Yes - new external source integration and questionable scraping/API behavior are approval-gated by `.ai/docs/escalation_rules.md`. Approved in-session on 2026-07-12 to proceed with MercadoLibre.

## Definition of Done
- [ ] `bin/rails test` green
- [ ] `.ai/STATUS.md` updated
- [ ] ADR recorded in `.ai/decisions/` if the change is architectural
- [ ] Spec/plan committed alongside the work (`docs/superpowers/`)
- [ ] Superseded docs marked, not abandoned
