# Saved Search Management Design

## Goal
Close the gap between the saved-search feed and user setup: users should be able to create, edit, and delete searches without console or seed data.

## Scope
Add `SearchPreferencesController` with `new`, `create`, `edit`, `update`, and `destroy`. The feature uses the existing `SearchPreference`, `SearchZone`, and `Zone` models; no migration is needed.

## Design
The sidebar gets a compact "New search" action. Search forms live on simple signed-in pages and expose existing fields: name, location query, zones, min/max price, minimum bedrooms, and notifications. Zone selection is checkbox-based using seeded zones. Create and update redirect to the feed with the saved search selected; delete redirects to the feed.

Ownership stays strict: every lookup is scoped through `current_user.search_preferences`, so users cannot edit, update, or delete someone else's search. Listings remain shared inventory and are never affected by deleting a search.

## Testing
Integration tests cover guest redirects, create/update/destroy happy paths, validation rendering, zone assignment, and ownership protection. Existing feed tests continue to cover sidebar rendering and selected-search behavior.
