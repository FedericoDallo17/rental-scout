# Saved Search Management Implementation Plan

**For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) superpowers:executing-plans implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax tracking.

**Goal:** Add signed-in create/edit/delete flow for saved searches using existing models.

**Architecture:** Add `SearchPreferencesController` scoped to `current_user.search_preferences`, shared form partial, simple signed-in pages, and sidebar actions. Use existing `Zone` records for checkbox assignment.

**Tech Stack:** Rails 8, Devise authentication, ERB, Minitest integration tests, existing CSS.

---

### Task 1: Controller Flow Tests

**Files:**
- Create: `test/controllers/search_preferences_controller_test.rb`

- [ ] Write failing tests for guest redirect, create with zones, validation failure, edit ownership, update, and destroy.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/controllers/search_preferences_controller_test.rb`.
- [ ] Expected failure: missing route/helper/controller.

### Task 2: Routes, Controller, and Forms

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/search_preferences_controller.rb`
- Create: `app/views/search_preferences/new.html.erb`
- Create: `app/views/search_preferences/edit.html.erb`
- Create: `app/views/search_preferences/_form.html.erb`
- Modify: `app/views/listings/index.html.erb`

- [ ] Add `resources :search_preferences, except: [:index, :show]`.
- [ ] Scope all record lookup through `current_user.search_preferences`.
- [ ] Permit `zone_ids: []` and scalar search fields.
- [ ] Render form validation errors without losing selected zones.
- [ ] Add sidebar "New search" and per-search "Edit" links.
- [ ] Run the focused controller test until green.

### Task 3: Styling and Mirror

**Files:**
- Modify: `app/assets/stylesheets/application.css`
- Modify: `public/stylesheets/application.css`

- [ ] Add compact search form styles and sidebar action styles.
- [ ] Copy app stylesheet to public mirror.
- [ ] Run `rtk rbenv exec ruby bin/rails test test/assets/stylesheet_mirror_test.rb`.

### Task 4: Docs and Verification

**Files:**
- Modify: `.ai/STATUS.md`
- Modify: `.ai/product/roadmap.md`

- [ ] Mark Ticket 019 landed and keep Ticket 018 paused on MercadoLibre API keys.
- [ ] Run focused tests.
- [ ] Run full `rtk rbenv exec ruby bin/rails test`.
- [ ] Commit at the ticket boundary.
