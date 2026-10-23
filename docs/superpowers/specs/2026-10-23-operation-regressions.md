# Operation-type regression fixes

The user requested fixing remaining test failures before commit/push. The queued
scrape-to-notification regression is a production normalization bug: Remax assigns
the requested operation to every result, so a rental returned during a sale query
can overwrite its rental identity and stop matching rental searches.

Preserve explicit provider operation metadata, normalizing rent/sale to
alquiler/venta. Use the requested operation only when metadata is absent; keep
unsupported explicit values outside the supported inventory scope. Preserve
notification idempotency. Test at the HTTP boundary without live scraping.

Update the sidebar regression to expect its existing operation-type label.
The tour assertion has already been updated by the concurrent tour work.
