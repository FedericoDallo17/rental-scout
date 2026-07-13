# Ticket: 029 - InfoCasas Price Currency

## Goal

Preserve each InfoCasas listing's advertised rent currency while keeping common
expenses in Uruguayan pesos.

## Acceptance Criteria

- InfoCasas `$` prices normalize to `UYU`.
- InfoCasas `U$S` prices normalize to `USD`.
- Common expenses normalize to `UYU` independently of rent currency.
- The acquisition request does not filter out dollar-priced listings.
- No live scrape is run; behavior is covered with provider-shaped HTTP fixtures.

## Evidence

A user-approved, one-request index probe on 2026-07-13 confirmed the response keys
`currency`, `currency_id`, and `commonExpenses_currency`. It also confirmed that
`currency_id: 2` and `$` represent UYU. The InfoCasas UI supplied by the user shows
`U$S` for USD rent and `$ ... GC` for UYU expenses.

