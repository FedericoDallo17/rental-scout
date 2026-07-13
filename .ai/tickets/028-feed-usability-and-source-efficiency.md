# Ticket: 028 - Feed Usability and Source Efficiency

## Goal

Shape the next feed refinement pass before implementation.

## Open TODOs

- [x] Align listing cards in each dashboard row despite different title and URL lengths.
- [x] Rename the user-facing `InfoCasas API` source label to `InfoCasas` without changing its adapter key.
- [ ] Decide whether the `Type` fact earns its permanent card space when providers omit it.
- [ ] Define incremental-fetch strategies per provider based on publication-date and ordering support.
- [ ] Revisit the meaning, explanation, and contrast of the 0–100 coincidence score.
- [ ] Design dashboard sorting/filtering, selected-search deselection, and an all-searches aggregate feed.

## Questions to Resolve

### Card facts

- Remove `Type`, show it only when present, or replace its slot with a more useful fact?
- Should cards use fixed title/fact/footer tracks or a compact content-driven layout?

### Source fetching

- InfoCasas supports the current `publicationDate` window.
- Remax supports recent-first ordering but no confirmed publication-date filter.
- Housi and Imperium have no confirmed publication-date filter in their current contracts.
- For sources without a window, decide between bounded recent pages with seen-ID stopping,
  conditional requests, and occasional full reconciliation.

### Coincidence score

- Current weights: price 60, bedrooms 25, detail completeness 15.
- Missing optional preferences receive neutral points, so `48/100 match` can mean “no
  budget, no bedroom constraint, and basic details,” not a measured preference match.
- Decide whether to split preference fit from listing completeness, rename the score,
  expose components, or remove the number when preferences are too broad.
- Increase visual contrast after the semantic decision.

### Dashboard controls

- Sorting candidates: newest, price, total monthly cost, score, and area.
- Filtering candidates: source, neighborhood, currency, expenses known, parking, and type.
- Clicking the active saved search should clear it.
- A cleared selection should show the union of all saved-search matches, deduplicated by
  listing, with an optional explicit “all fresh inventory” mode kept distinct.

## Human Approval Required?

Yes. Product semantics and provider request behavior require user decisions before implementation.

## Delivered Slice

Ticket 028A was completed on 2026-07-13. Cards now use bounded title,
explanation, location, and URL tracks; `InfoCasas` is the product-facing label while
`info_casas_api` remains the adapter key. The remaining items stay approval-gated.

## Definition of Done

- [ ] Product decisions recorded
- [ ] Design spec and implementation plan written
- [ ] `bin/rails test` green after implementation
- [ ] `.ai/STATUS.md` updated
