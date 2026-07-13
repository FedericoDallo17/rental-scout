# Ticket: 030 - Saved Search Price Currency

## Goal

Let users state whether saved-search price limits are in UYU or USD so unlike
currencies are never compared.

## Acceptance Criteria

- Saved searches persist `UYU` or `USD`; existing rows default to `UYU`.
- New and edit forms expose a localized currency selector.
- Price-bounded feeds only compare listings in the selected currency.
- Searches without price bounds continue to include both currencies.
- Score calculations never compare unlike currencies.

## Human Approval

Approved by the user on 2026-07-13, including the required migration.

