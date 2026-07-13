# Provider Location Validation

Date: 2026-07-12. Scope: one read-only search page and one canonical URL per
provider; no intake, scraping run, job enqueue, persistence, or notification.

| Source | Results | Neighborhoods | Coordinates | Malformed | Sample URL |
|---|---:|---:|---:|---:|---:|
| Remax | 49 | 23 | 49 (100%) | 0 | HTTP 200 |
| Housi | 20 | 15 | 0 (0%) | 0 | HTTP 200 |
| Imperium | 17 | 9 | 0 (0%) | 0 | HTTP 200 |
| InfoCasas | 50 | 20 | 0 (0%) | 0 | HTTP 200 |

City-wide diversity is present for every source. The unrestricted Remax response also
contains non-Montevideo locations; its normalized city metadata lets intake reject
those through the existing scope validator. All sampled canonical URLs resolve.

One detail page was inspected for each zero-coordinate source. InfoCasas returned
usable latitude/longitude through the existing JSON-LD extractor. The sampled Housi
and Imperium pages did not expose coordinate fields. Therefore InfoCasas is the next
coverage target: run the existing detail backfill once daily with a hard limit of 20
listings. Housi and Imperium remain candidates for a future cached address-geocoding
ticket, subject to provider/licensing and rate-limit decisions.

The selected strategy was validated against three existing InfoCasas listings: all
three detail requests produced coordinates and all three records became spatially
resolved. No scrape run or notification was triggered.
