# Timbre first-search onboarding

Implemented locally for the user's request to improve onboarding using the new
brand identity. No commit or deployment: the working tree contains prior branding,
operation-type/scraping/filter work and concurrent navigation/notification edits.

## Delivered

- Accounts without searches see a personalized branded welcome with one primary
  first-search action and a secondary public-tour link.
- First-search form: neighborhoods (accent-insensitive filter), operation,
  budget/currency/expenses, bedrooms, optional minimum price/area, name and alerts.
  Three progressively enhanced steps; back navigation, keyboard focus and live
  summary. Without JS all panels and the submit action are available.
- Existing accounts retain the normal editor. A submitted onboarding flag cannot
  trigger first-search completion for an account with existing searches.
- First-save receipt is consumed by ListingsController before flash rendering,
  so internal state is never shown as a message. Completion distinguishes muted
  alerts, connected browser/active Pushover delivery, and incomplete setup.
- First search with no matches gets an honest saved/waiting state and edit link.
- ES/EN copy, Patio palette, local Manrope and approved door asset. Scoped CSS
  remains byte-identical in both application stylesheet copies.

## Verification

- Before implementation: 310 tests, 1870 assertions, 2 failures: existing sidebar
  operation label assertion and queued scraper delivery fixture.
- Final full suite: 323 tests, 2012 assertions, 3 failures. The two original failures
  remain; concurrent public-tour changes also produce 4 forms where the tour test
  expects 2. No onboarding failures. Notification setup ordering briefly failed
  during concurrent edits and passed in the final full run.
- 9 onboarding integration cases pass (61 assertions), including an actual
  zone/budget-matched listing, rejection of an over-budget listing, failed-save
  zone/currency/budget retention, first-save receipt lifetime, and alert readiness.
- Focused controller/auth/language/stylesheet/onboarding suite: 64 tests.
- JavaScript syntax, CSS mirror comparison and git diff whitespace checks pass.
- Chrome desktop: welcome and all steps rendered; neighborhood filtering without
  accents, no-match state, retained selected neighborhood, currency/budget/expense
  summary and saving to a real local saved search exercised. Screenshot review
  covered welcome, neighborhood step and preferences. At 390px the last step,
  primary submit action and search summary were inspected without horizontal
  clipping. The initial receipt exposed an internal flash ID; fixed and covered
  by an assertion that exactly one user-facing app flash remains.
- Chrome then blocked automation because another extension UI opened. The async
  user request to dismiss it is pending. Remaining visual QA: welcome and all
  steps at 390/320px, final receipt after the fix, failed-save UI, no-JS, Turbo
  restoration and keyboard validation. Browser viewport override was reset.
- No live scraping, real notification delivery or browser permission prompt.

## Local review

Server was already running at `http://127.0.0.1:3127`. The onboarding appears at
`/listings` and `/search_preferences/new` only when the signed-in account has no
saved searches. Local QA accounts created for this check:
`timbre-onboarding-qa@example.test` (has the saved search from functional QA) and
`timbre-onboarding-mobile-qa@example.test` (no saved search when created). Credentials
were used only for local testing; do not deploy these accounts or copy their data.

Continue visual QA after Chrome is available; keep the existing unrelated edits
separate when committing.
