# Scraping Runs Observability Implementation Plan

**For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) superpowers:executing-plans implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax tracking.

**Goal:** Add a signed-in `/scraping_runs` page that makes scrape outcomes and source failures visible.

**Architecture:** Use existing `ScrapingRun` and `ScrapingSourceRun` records. Add a read-only controller/view and a header navigation link; eager-load source runs and listing sources in the controller.

**Tech Stack:** Rails 8, Devise authentication, ERB views, Minitest integration tests, existing CSS.

---

### Task 1: Add Failing Observability Tests

**Files:**
- Create: `test/controllers/scraping_runs_controller_test.rb`

- [ ] Write tests for guest redirect, signed-in run summary rendering, per-source failure rendering, and the header link.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/controllers/scraping_runs_controller_test.rb`.
- [ ] Expected failure: route/helper/controller for `scraping_runs` is missing.

### Task 2: Implement Route, Controller, and View

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/scraping_runs_controller.rb`
- Create: `app/views/scraping_runs/index.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] Add `resources :scraping_runs, only: [:index]`.
- [ ] Add `ScrapingRunsController#index` that loads recent runs with `scraping_source_runs: :listing_source`.
- [ ] Add a compact ERB page that renders run summaries and source-run error messages.
- [ ] Add a signed-in header link to `scraping_runs_path`.
- [ ] Run the focused controller test and make it pass.

### Task 3: Style and Mirror CSS

**Files:**
- Modify: `app/assets/stylesheets/application.css`
- Modify: `public/stylesheets/application.css`

- [ ] Add styles for the runs page, status chips, and source-run rows.
- [ ] Copy the stylesheet to the public mirror.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/assets/stylesheet_mirror_test.rb`.

### Task 4: Update Project State and Verify

**Files:**
- Modify: `.ai/STATUS.md`
- Modify: `.ai/product/roadmap.md`

- [ ] Mark Ticket 011 observability as done/currently landed while MercadoLibre remains blocked on API keys.
- [ ] Run focused tests for controller, stylesheet mirror, and bootstrap config.
- [ ] Run full `rtk rbenv exec ruby bin/rails test`.
- [ ] Commit docs and code at the ticket boundary.
