# Hybrid Workbench Polish Design

## Goal
Apply the approved Hybrid Workbench direction to the new saved-search management and scraping-run observability features.

## Direction
Keep the listing feed as the main product surface. Saved-search management and scraper observability should feel like compact tools around that feed, not separate marketing pages or heavy admin screens.

## Changes
- Saved-search sidebar entries become compact workbench items with search name, query, match count, and a small edit action.
- The saved-search form gets a two-column workbench layout: form controls on the left, concise feed/notification context on the right.
- The scraping-runs page gets a tighter operational shell and a small subnav back to the feed.
- Styling stays within the existing warm neutral palette and dense operational UI.

## Testing
Tests assert the new structural classes and count/context text. Existing stylesheet mirror and full Rails tests remain required.
