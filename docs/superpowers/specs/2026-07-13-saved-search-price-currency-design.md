# Ticket 030: Saved Search Price Currency

Add `price_currency` to saved searches as a required `UYU`/`USD` value with a
database default of `UYU`. This safely preserves existing search behavior.

Currency only governs min/max price limits. When either limit is present, the feed
first selects listings with the search currency and then applies the numeric bounds.
Without price limits, the feed remains mixed-currency. No conversion or exchange-rate
dependency is introduced.

The bilingual search form exposes the selector alongside price fields. The model
validates the supported values, and scoring treats a mismatched currency as
non-comparable rather than calculating a misleading percentage.

