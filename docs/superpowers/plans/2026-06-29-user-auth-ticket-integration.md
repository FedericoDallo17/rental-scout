# User Auth Ticket Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the approved user-auth planning work into the repo by adding ticket docs 014-017, updating roadmap/status documentation, and locking the new planning baseline with regression tests.

**Architecture:** Treat this as documentation integration work, not application-feature implementation. The deliverable is a consistent `.ai` planning surface: concrete ticket files for the new auth track, a roadmap that acknowledges the new workstream, and status/tests that no longer pretend scraper tickets are the only next option.

**Tech Stack:** Markdown, Rails repo documentation, `.ai` planning files, Minitest documentation regression checks

## Global Constraints

- Add auth as new work, not as an implicit assumption.
- Use email/password authentication.
- Keep external notification identity separate from login.
- Keep the auth foundation ticket narrow.
- Split follow-up ownership, favorites, and notification identity into separate tickets.
- Ticket 014 should include registration, login, logout, session handling, and a base `User` model.
- Ticket 014 should not include attaching preferences, searches, listings, or matches to users.
- Ticket 017 should treat Pushover identity as notification configuration, not authentication.

---

## Scope Check

The approved spec defines four future implementation tickets, which are independent product subsystems. This plan does **not** implement those features. It only integrates the new ticket set into the repo’s planning/documentation system so Ticket 014, 015, 016, and 017 can be selected later and planned individually.

## File Structure Map

- `/.ai/tickets/014-user-accounts-and-session-authentication.md` — new foundational auth ticket
- `/.ai/tickets/015-user-owned-dashboard-and-search-data.md` — new ownership/scoping ticket
- `/.ai/tickets/016-favorites-for-searches-and-matches.md` — new favorites ticket
- `/.ai/tickets/017-pushover-notification-identity.md` — new notification-identity ticket
- `/.ai/product/roadmap.md` — roadmap updated so auth/user ownership work appears explicitly
- `/.ai/STATUS.md` — current project status updated so next-step guidance includes the auth track
- `test/config/bootstrap_config_test.rb` — documentation regression coverage for the new ticket set, roadmap wording, and status baseline

### Task 1: Add regression tests for the new auth planning artifacts

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: `/Users/fededallo/Desktop/rental-scout-lite/docs/superpowers/specs/2026-06-29-user-auth-ticket-design.md`
- Produces: failing tests that require auth ticket docs and roadmap language to exist before documentation integration is considered complete

- [ ] **Step 1: Write the failing documentation regression tests**

```ruby
test "auth planning tickets exist with expected titles" do
  {
    ".ai/tickets/014-user-accounts-and-session-authentication.md" => "# Ticket: 014 - User Accounts and Session Authentication",
    ".ai/tickets/015-user-owned-dashboard-and-search-data.md" => "# Ticket: 015 - User-Owned Dashboard and Search Data",
    ".ai/tickets/016-favorites-for-searches-and-matches.md" => "# Ticket: 016 - Favorites for Searches and Matches",
    ".ai/tickets/017-pushover-notification-identity.md" => "# Ticket: 017 - Pushover Notification Identity"
  }.each do |relative_path, title|
    path = Rails.root.join(relative_path)

    assert path.file?, "expected #{relative_path} to exist"
    assert_includes path.read, title
  end
end

test "roadmap includes the user auth planning track" do
  roadmap = Rails.root.join(".ai/product/roadmap.md").read

  assert_includes roadmap, "User accounts and session authentication"
  assert_includes roadmap, "User-owned dashboard and search data"
  assert_includes roadmap, "Favorites for searches and matches"
  assert_includes roadmap, "Pushover notification identity"
end
```

- [ ] **Step 2: Run the focused test file to verify it fails**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL because ticket files 014-017 do not exist and roadmap does not mention the auth track yet

- [ ] **Step 3: Insert these new tests into `test/config/bootstrap_config_test.rb` right before the existing status-baseline test**

```ruby
test "auth planning tickets exist with expected titles" do
  {
    ".ai/tickets/014-user-accounts-and-session-authentication.md" => "# Ticket: 014 - User Accounts and Session Authentication",
    ".ai/tickets/015-user-owned-dashboard-and-search-data.md" => "# Ticket: 015 - User-Owned Dashboard and Search Data",
    ".ai/tickets/016-favorites-for-searches-and-matches.md" => "# Ticket: 016 - Favorites for Searches and Matches",
    ".ai/tickets/017-pushover-notification-identity.md" => "# Ticket: 017 - Pushover Notification Identity"
  }.each do |relative_path, title|
    path = Rails.root.join(relative_path)

    assert path.file?, "expected #{relative_path} to exist"
    assert_includes path.read, title
  end
end

test "roadmap includes the user auth planning track" do
  roadmap = Rails.root.join(".ai/product/roadmap.md").read

  assert_includes roadmap, "User accounts and session authentication"
  assert_includes roadmap, "User-owned dashboard and search data"
  assert_includes roadmap, "Favorites for searches and matches"
  assert_includes roadmap, "Pushover notification identity"
end
```

- [ ] **Step 4: Run the focused test file again to confirm the failure is still the intended one**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL only on missing auth ticket files, missing roadmap entries, and the still-old status baseline

- [ ] **Step 5: Commit the failing-test scaffold**

```bash
git add test/config/bootstrap_config_test.rb
git commit -m "test: cover auth planning artifacts"
```

### Task 2: Add the new ticket docs and roadmap entries

**Files:**
- Create: `/Users/fededallo/Desktop/rental-scout-lite/.ai/tickets/014-user-accounts-and-session-authentication.md`
- Create: `/Users/fededallo/Desktop/rental-scout-lite/.ai/tickets/015-user-owned-dashboard-and-search-data.md`
- Create: `/Users/fededallo/Desktop/rental-scout-lite/.ai/tickets/016-favorites-for-searches-and-matches.md`
- Create: `/Users/fededallo/Desktop/rental-scout-lite/.ai/tickets/017-pushover-notification-identity.md`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/.ai/product/roadmap.md`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: Task 1 failing tests; `/Users/fededallo/Desktop/rental-scout-lite/docs/superpowers/specs/2026-06-29-user-auth-ticket-design.md`
- Produces: concrete ticket files 014-017 and roadmap language future ticket-selection work can rely on

- [ ] **Step 1: Create Ticket 014 exactly from the approved scope**

```markdown
# Ticket: 014 - User Accounts and Session Authentication

## Goal
Introduce email/password user accounts and session authentication so the app can identify a current user consistently.

## Acceptance Criteria
- Users can register with email and password.
- Users can log in with email and password.
- Users can log out.
- A `User` model exists with a unique email.
- Passwords are stored securely rather than in plain text.
- Authenticated session state persists across requests.
- Protected pages require an authenticated user.
- Guest users are redirected to sign in.
- Tests cover registration, login, logout, and protected-route access.

## Human Approval Required?
Yes
```

- [ ] **Step 2: Create Tickets 015-017 from the approved follow-up boundaries**

```markdown
# Ticket: 015 - User-Owned Dashboard and Search Data

## Goal
Attach product data and dashboard visibility to the authenticated user so each user sees and manages only their own app data.

## Acceptance Criteria
- Preferences are associated with `User`.
- Saved searches are associated with `User`.
- Any dashboard-visible search results or match/feed records used by the app at implementation time are associated with `User` or are derived only from that user's owned records.
- User-facing data queries are scoped to the current user.
- A user cannot view another user's dashboard/search data through normal app flows.
- Tests cover ownership and access boundaries.

## Human Approval Required?
Yes
```

```markdown
# Ticket: 016 - Favorites for Searches and Matches

## Goal
Allow users to save favorites for searches and matches without coupling that behavior to authentication itself.

## Acceptance Criteria
- Users can favorite saved searches.
- Users can favorite the user-visible listing or match records that appear in the personalized dashboard/feed at implementation time.
- Favorites are scoped to the current user.
- Tests cover favorite creation and retrieval behavior.

## Human Approval Required?
Yes
```

```markdown
# Ticket: 017 - Pushover Notification Identity

## Goal
Store the user-specific notification identity/config needed for later Pushover delivery, while keeping it separate from login credentials.

## Acceptance Criteria
- The user model or a related record can store the notification identity/config needed for Pushover.
- Notification identity is explicitly separate from authentication credentials.
- Later notification work can depend on this ticket without changing the login approach.
- Tests cover persistence and basic validation of the notification identity fields.

## Human Approval Required?
Yes
```

- [ ] **Step 3: Update the roadmap so the auth track is explicit**

```markdown
# Roadmap

## Phase A
- Discovery
- Look and feel
- MVP scope
- Mock source adapter
- Portal listing surface

## Phase B
- User accounts and session authentication
- User-owned dashboard and search data
- Favorites for searches and matches
- Pushover notification identity

## Phase C
- Hourly job
- Deduplication
- Run observability
- Notification events

## Phase D
- Real source adapter spike
```

- [ ] **Step 4: Run the focused documentation regression test**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL only on the status baseline test because the ticket files and roadmap now exist but `.ai/STATUS.md` still reflects the old scraper-only next-step guidance

- [ ] **Step 5: Commit the ticket and roadmap additions**

```bash
git add .ai/tickets/014-user-accounts-and-session-authentication.md .ai/tickets/015-user-owned-dashboard-and-search-data.md .ai/tickets/016-favorites-for-searches-and-matches.md .ai/tickets/017-pushover-notification-identity.md .ai/product/roadmap.md
git commit -m "docs: add auth planning tickets"
```

### Task 3: Update status to reflect the broader next-ticket choices

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/.ai/STATUS.md`
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: Task 2 ticket set and roadmap
- Produces: a status baseline that acknowledges the auth planning track and no longer claims scraper implementation is the only next path

- [ ] **Step 1: Write the new expected status baseline in the test helper method**

```ruby
def expected_status_baseline
  <<~MARKDOWN
    # Status

    ## Current Phase
    Bootstrap complete

    ## Current Task
    Awaiting next prioritized implementation ticket

    ## Status
    Done

    ## Done
    - Docs and tickets created
    - Rails app initialized
    - Core models added
    - Mock scraper pipeline added
    - Initial portal added
    - Scraper domain ADR defined
    - User auth ticket track defined

    ## Doing
    - None

    ## Blockers
    - None

    ## Risks
    - Real source adapters, auth, and notification delivery still require careful escalation

    ## Human Input Needed
    - Choose the next implementation ticket

    ## Next Step
    Execute Ticket 008, 009, or 014 based on current product priority
  MARKDOWN
end
```

- [ ] **Step 2: Run the focused test to verify it fails only because `.ai/STATUS.md` is still old**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL on `status matches the user auth planning baseline`

- [ ] **Step 3: Update `.ai/STATUS.md` to match the new baseline exactly**

```markdown
# Status

## Current Phase
Bootstrap complete

## Current Task
Awaiting next prioritized implementation ticket

## Status
Done

## Done
- Docs and tickets created
- Rails app initialized
- Core models added
- Mock scraper pipeline added
- Initial portal added
- Scraper domain ADR defined
- User auth ticket track defined

## Doing
- None

## Blockers
- None

## Risks
- Real source adapters, auth, and notification delivery still require careful escalation

## Human Input Needed
- Choose the next implementation ticket

## Next Step
Execute Ticket 008, 009, or 014 based on current product priority
```

- [ ] **Step 4: Run the focused test file to verify the documentation baseline passes**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: PASS

- [ ] **Step 5: Commit the status alignment**

```bash
git add .ai/STATUS.md test/config/bootstrap_config_test.rb
git commit -m "docs: update auth planning status"
```

## Verification Checklist

- Run `bin/rails test test/config/bootstrap_config_test.rb`
- Confirm all four new ticket files exist under `.ai/tickets/`
- Confirm `.ai/product/roadmap.md` mentions the auth planning track explicitly
- Confirm `.ai/STATUS.md` includes Ticket 014 as a valid next-step option

## Follow-Up

After this documentation integration lands, write a separate implementation plan for whichever ticket is chosen next:
- Ticket 008 if the immediate priority remains improving the mock feed
- Ticket 009 if the immediate priority is the scraping job path
- Ticket 014 if the immediate priority is introducing user auth before deeper personalization
