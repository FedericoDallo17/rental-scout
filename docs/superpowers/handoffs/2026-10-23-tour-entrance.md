# Timbre tour entrance

Implemented locally in the existing `/tour` route. The first scene is a full-screen
green/ivory brand stage: the isolated symbol grows into place, yellow sound rings
invite activation, and a click plays the approved D2 door opening and wordmark
reveal before entering the journey. The SVG is now a shared `brand_art` partial;
the existing login animator retains automatic/replay behavior. Manual scenes use
an explicit playback event and completion signal, with unique SVG clip IDs.

The journey now uses an open two-column chapter layout and horizontal navigation;
phones/tablets use a compact five-step rail. All fictional-data interactions remain.
Spanish/English, keyboard activation, skip, reduced-motion branches, deep links,
fallback when Web Animations is missing and Turbo disposal/restoration are covered
in implementation. Without JS the entrance stays hidden and all chapters are readable.

Validation:
- Focused Rails tests: 6 tests, 72 assertions, no failures (tour controller, brand
  metadata/assets and byte-identical stylesheet mirror).
- Node syntax checks passed for both modified JS files; git diff --check passed.
- Browser QA at desktop and 320/375/414/768 px: entrance, language switching,
  click-to-open and reveal, keyboard skip, direct chapter loading, budget empty
  state, favorite toggle, visited status, notification preview and login/back
  restoration. No horizontal document overflow at inspected widths; console clean.
- Reduced motion is implemented but was not emulated during this browser pass.
- Full suite: 323 tests, 2022 assertions, two failures in other working-tree areas:
  `RunScrapersJobTest#test_carries_a_stubbed_provider_listing_through_queued_delivery_without_duplicates`
  (expected delivery count 1, got 0) and
  `ListingsFlowTest#test_signed_in_listings_route_shows_saved_searches_sidebar_and_listings_grid`
  (expected sidebar label `Pocitos`, got `Pocitos · Rentals`). No fixes made to those
  concurrently modified product areas in this task.

No deployment or commit. The working tree contains multiple concurrent changes;
tour changes are documented separately in the matching spec/plan. Preview:
`http://127.0.0.1:3127/tour`.
