# InfoCasas sale classification fix

## Cause and change

Production image `2bf3f6e2273d736b41be25ca6c263cf2699177c9` recognized only InfoCasas operation ID 2. Sale ID 1 fell through to the first URL path segment, storing descriptive slugs or `proyectos` as operations. Intake persisted them with `in_scope=false`, `scope_rejection_reason=unknown_operation`; scraper execution could still succeed.

Map exact numeric/string IDs 1 and 2 to `venta` and `alquiler`. Explicit unknown IDs resolve to `unknown` and stay out of scope. Without an ID, accept only exact legacy `venta`/`alquiler` URL segments, otherwise use the operation requested from the provider. Provider metadata takes precedence over conflicting URLs and requests.

## Verification before push

- Added four HTTP-boundary regression tests. All four failed before the change; focused suite then passed: 21 tests, 87 assertions.
- Full Rails suite: 340 tests, 2158 assertions, zero failures/errors/skips (`PARALLEL_WORKERS=1`).
- Ran corrected InfoCasas code inside an isolated production Rails runner process. No application files, inventory, notification events or scraping runs were changed.
- Exactly one live sale index HTTP request per active provider. Disabled Net::HTTP automatic retries and limited each paginated adapter to one page in that process. No detail calls or reconciliation. All responses HTTP 200.

| Provider | HTTP requests | Normalized sales | In Montevideo scope | Outside Montevideo |
| --- | ---: | ---: | ---: | ---: |
| InfoCasas | 1 | 50 | 50 | 0 |
| Remax | 1 | 50 | 43 | 7 |
| Housi | 1 | 20 | 20 | 0 |
| Imperium Inmobiliaria | 1 | 8 | 1 | 7 |

All normalized listings had required intake attributes, `venta`, USD/UYU currency and HTTPS canonical URLs. Scope exclusions were only `outside_montevideo`. Replayed each captured response through public `fetch_listings` with identical results and no additional HTTP calls. These checks cover one live sale page per source, not every page or rental operation.

## Existing data

Investigation found 2,920 invalid operation records, all InfoCasas and all rejected as `unknown_operation`. Existing normalized `raw_payload` does not retain the original operation ID. Do not blindly relabel every invalid operation as sale. This change repairs future imports and records encountered again by normal intake. Source-verified historical recovery is still pending and was not run, respecting the single-request-per-provider constraint.

The original workspace volume was unavailable; the change was prepared in `/private/tmp/timbre-sale-fix`, cloned from `FedericoDallo17/rental-scout` at the deployed commit.
