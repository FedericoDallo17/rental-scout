# Timbre navigation and content hierarchy

Implemented the user's navigation/content review locally. Production is unchanged.

- Results is the first authenticated tab on desktop and mobile, followed by saved
  apartments, Chimes and Alerts. Shared navigation partial keeps ordering/routes
  aligned. Results stays active at root, with filters, and while editing searches.
- The public recruiter tour no longer appears in authenticated primary/account
  navigation. Its guest entry remains on sign-in. Mobile account controls remain
  in the menu; all four product destinations stay directly visible below.
- Personal Chimes begins with user-isolated notification history or its empty
  state. Removed duplicated location diagnostics and their global metrics query.
  Existing admin-only diagnostics and their tests remain intact.
- Alerts now leads with a short explanation and the existing device activation
  control. Account-wide state follows it. Device help, optional Pushover setup,
  privacy and troubleshooting use native disclosures. Existing validation,
  subscription behavior, pause/resume/removal and test delivery are unchanged.
- Patio/Manrope styling retained; CSS compatibility mirror remains byte-identical.

Validation:

- Focused Rails checks initially passed: 37 tests, 413 assertions, no failures,
  including the public tour tests before concurrent tour-entrance work.
  Final navigation/settings/history/CSS run: 34 tests, 386 assertions, no failures.
- Chrome QA passed in 15 captures with no runtime/local-request failures or
  horizontal overflow. Desktop 1440/1024/768 and mobile 390/320; real link clicks,
  active destinations, activation above the fold, all disclosure open/close cycles,
  account-menu Escape, and native help with JavaScript disabled.
  Evidence: `/private/tmp/timbre-navigation-qa/receipt.json` and adjacent PNGs.
- Full suite at the latest run: 322 tests, 2000 assertions, 3 failures. Two are the
  prior operation-type/scraper failures (`listings_flow_test.rb:169`,
  `run_scrapers_job_test.rb:247`). The third is `tours_controller_test.rb:13`:
  expects two forms but concurrent tour-entrance work adds a second language
  switcher, giving four. Left that separate in-flight work untouched.
- The first full-suite attempt with redirected output was blocked by sandbox
  PostgreSQL socket permissions; the reported full result came from the successful
  escalated test execution. `git diff --check` passes.

The existing local dummy session and sample searches/favorites/chimes are retained
for the user. The local preview is at `http://127.0.0.1:3127`.

Keep operation-type, provider, onboarding and tour-entrance work separate when
committing/releasing; these files are changing concurrently. This task did not
send notifications, run scrapers, alter authentication, or deploy.
