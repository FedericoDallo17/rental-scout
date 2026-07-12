# Ticket: 019 - Saved Search Management

## Goal
Let signed-in users create, edit, and delete their own saved searches from the app UI.

## Acceptance Criteria
- Signed-in users can create a saved search with name, location query, zones, optional price bounds, optional minimum bedrooms, and notifications enabled/disabled.
- Signed-in users can edit and delete only their own saved searches.
- Saved searches appear in the existing sidebar and redirect back to the filtered feed after create/update.
- Deleting a saved search redirects to the feed and never deletes listings.
- Guests are redirected to sign in.
- Tests cover ownership, validation failure rendering, zone assignment, and sidebar links.

## Human Approval Required?
No

## Definition of Done
- [ ] `bin/rails test` green
- [ ] `.ai/STATUS.md` updated
- [ ] ADR recorded in `.ai/decisions/` if the change is architectural
- [ ] Spec/plan committed alongside the work (`docs/superpowers/`)
- [ ] Superseded docs marked, not abandoned
