# Ticket: 032 - Preference Fit Score

## Goal

Make the listing score describe actual saved-search preference fit rather than a
mixture of preferences and provider data completeness.

## Acceptance Criteria

- Price contributes 70% and bedrooms 30% when both preferences are active.
- A single active preference is normalized to the full 0–100 range.
- Broad searches without a maximum price or minimum bedrooms show no number.
- Listing completeness appears separately and never changes preference fit.
- Score copy and colors are readable in English and Spanish.

## Human Approval

Approved by the user on 2026-07-13.

