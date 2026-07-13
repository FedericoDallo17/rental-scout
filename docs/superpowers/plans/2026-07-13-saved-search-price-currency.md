# Ticket 030 Implementation Plan

1. Add the approved `price_currency` migration with a non-null UYU default.
2. Add failing model, feed, controller, and scoring coverage.
3. Validate and permit the currency, render the bilingual selector, and use it in
   feed filtering and score comparison.
4. Migrate development and test databases.
5. Run focused tests and the full suite.
6. Update project status and roadmap, then commit the completed ticket.

