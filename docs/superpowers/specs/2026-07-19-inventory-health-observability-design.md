# Inventory-health observability design

The existing runs workbench becomes an admin-only operational surface, while ordinary users retain a private run-match history. The admin surface combines run outcomes, source-local third-party request counts, location-quality metrics, source activation, and guarded maintenance actions.

Each `ScrapingRun` durably records whether it was an ordinary hourly acquisition or a reconciliation. Each `ScrapingSourceRun` records provider requests made during that source attempt, while `ListingSource` retains a lifetime counter that also includes coordinate backfill. Request hooks live at the adapter HTTP boundary so retries and pages are counted rather than inferred from listing totals.

Maintenance actions enqueue existing jobs and never call providers in the request. Acquisition and reconciliation are rejected while another scrape run is marked running. Admin authorization returns not found to avoid exposing operational routes. Recurring YAML is parsed in tests so job classes, schedules, and arguments are verified as loadable data.
