# Ticket 033: Aggregate Feed Controls

The unselected dashboard state represents the deduplicated union of the current
user's saved-search matches, not all scraped inventory. A selected search remains a
focused view; its active sidebar link points back to the unselected aggregate state.

`Listings::SavedSearchMatches` composes each search relation into one SQL `UNION ALL`
query and returns both search-to-listing and listing-to-search indexes. This supports
counts, deduplication, and aggregate match badges without one executed query per
saved search.

Server-side GET controls preserve selected-search state. Filters cover source,
resolved neighborhood, currency, and known expenses. Sorting covers newest, price
low/high, best fit, and known total monthly cost. Currency is always part of monetary
sort keys. Total monthly cost is only considered known when rent and expenses share a
currency; cross-currency totals sort after known totals rather than being added.

In aggregate mode, a card uses its highest preference-fit result among the searches
it matches. Completeness remains listing-specific. All-fresh-inventory browsing is
not conflated with this state and remains out of scope.

