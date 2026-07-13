# Ticket 028A: Feed Card Alignment and Source Labels

## Scope

This first Ticket 028 slice implements only decisions that do not change matching,
filtering, scoring, or provider request behavior.

- Listing cards reserve consistent visual tracks for explanations, titles, locations,
  facts, and URLs. Long titles and URLs are clamped to two lines so neighboring cards
  stay aligned without increasing row height unpredictably.
- The persisted adapter key remains `info_casas_api`, while every user-facing source
  label renders as `InfoCasas`.
- Internal adapter keys are not shown in the source controls.

## Design

`ListingSource#display_name` owns the boundary between internal provider identity and
product copy. It maps `info_casas_api` to `InfoCasas` and falls back to the persisted
name for every other source. Views and user-facing diagnostics use this method; jobs
and adapter lookup continue to use `adapter_key` unchanged.

Card alignment remains CSS-only. The card body fills its card, the fact grid consumes
the flexible space, and text-heavy tracks use fixed two-line bounds with ellipsis.
The mobile one-column layout keeps the same compact cards.

## Out of Scope

- Removing or replacing the Type fact
- Coincidence-score semantics or color
- Feed sorting, filtering, deselection, or aggregate views
- Incremental provider fetching

