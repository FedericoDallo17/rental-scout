# Ticket 007 Scraper Domain ADR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and integrate the Ticket 007 technical ADR that defines Rental Scout Lite’s scraper domain, its relationship to `../home_scraper` and `../scraper`, and the stable/provisional boundaries needed for the next scraper tickets.

**Architecture:** Treat this ticket as technical documentation work anchored in the current codebase and prior working systems. The implementation should create a durable ADR in `.ai/decisions/`, align the project’s existing ADR template and status knowledge with that decision, and avoid changing production code in this ticket.

**Tech Stack:** Markdown, Rails repo documentation, `.ai` decision records, existing scraper domain models

## Global Constraints

- Use a Rails monorepo as the default architecture.
- The portal is the primary user-facing surface.
- The scraper/job pipeline is the primary backend engine.
- Scraper behavior should stay close to `../home_scraper`, because that worked.
- Application/domain structure should be heavily inspired by `../scraper`, because that expresses the intended app design.
- Keep structure simple.
- Do not over-automate.
- Ticket 007 should produce a technical ADR.
- The ADR should define invariants for deduplication, “new listing” detection, and notification idempotency.
- The ADR should mark revisitable areas explicitly rather than pretending every decision is final.

---

## File Structure Map

- `/.ai/decisions/adr-scraper-domain.md` — final Ticket 007 architecture decision record
- `/.ai/templates/adr.md` — updated reusable ADR template so future ADRs match the project’s chosen structure
- `/.ai/STATUS.md` — updated to reflect that Ticket 007 has been completed and what it established
- `test/config/bootstrap_config_test.rb` — documentation-level regression checks for the existence and key content of the ADR artifacts

### Task 1: Create the scraper domain ADR document

**Files:**
- Create: `/Users/fededallo/Desktop/rental-scout-lite/.ai/decisions/adr-scraper-domain.md`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: `/Users/fededallo/Desktop/rental-scout-lite/docs/superpowers/specs/2026-06-28-ticket-007-scraper-domain-adr-design.md`
- Produces: the concrete ADR file referenced by Ticket 007 and future scraper/domain work

- [ ] **Step 1: Write the failing documentation regression test**

```ruby
test "scraper domain ADR exists with required references" do
  adr_path = Rails.root.join(".ai/decisions/adr-scraper-domain.md")

  assert adr_path.file?, "expected scraper ADR to exist"

  adr = adr_path.read
  assert_includes adr, "../home_scraper"
  assert_includes adr, "../scraper"
  assert_includes adr, "ScrapingRun"
  assert_includes adr, "ScrapingSourceRun"
  assert_includes adr, "NotificationEvent"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL because the ADR file does not exist yet

- [ ] **Step 3: Write the ADR using the approved design**

```markdown
# ADR: Scraper Domain

## Status
Accepted

## Context
Rental Scout Lite continues a validated idea. `../home_scraper` proved the scraper-and-notification loop in practice. `../scraper` was the hand-built attempt to wrap that behavior in a fuller application, and its technical decisions still reflect the intended app direction.

The project therefore needs a domain record that says:
- scraper behavior should stay close to `../home_scraper`
- application/domain structure should be heavily inspired by `../scraper`
- the current core entities are stable enough for the next tickets, but some areas remain explicitly provisional

## Decision
The scraper domain is defined around these concepts:
- `Listing`: normalized apartment record used by the app
- `ListingSource`: source registry/runtime anchor for one provider feed
- `ScrapingRun`: one top-level scheduler-triggered scraping execution
- `ScrapingSourceRun`: one source-specific outcome inside a `ScrapingRun`
- `SeenListing`: deduplication memory used for repeated-run safety
- `NotificationEvent`: recorded notification-worthy event, distinct from delivery

Deduplication rules:
1. Prefer `source + external_id` when external ID exists.
2. Fallback to `source + canonical_url` when external ID is absent or unstable.

“New listing” means newly discovered relative to deduplication state, not merely present in the latest scrape.

Notification idempotency rule:
- the same listing should not create duplicate notification events for the same logical notification context once already recognized and recorded.

Relationship to prior systems:
- keep scraper loop behavior close to `../home_scraper`
- keep application/domain direction heavily inspired by `../scraper`

Provisional areas:
- how far saved-search modeling should converge with `../scraper`
- whether `Match` becomes a persisted model
- whether source registry and adapter identity should separate further later

## Consequences
- Tickets 008 and 009 now have an explicit domain baseline.
- Current bootstrap models are acceptable as a starting point, but not beyond review or reshaping.
- Future scraper changes should be justified against this ADR instead of implicit chat history.

## Related Tickets
- 007-scraper-domain-design
- 008-mock-source-adapter
- 009-hourly-scraping-job
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: PASS


### Task 2: Update the reusable ADR template to match the project’s chosen shape

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/.ai/templates/adr.md`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: Task 1 ADR structure
- Produces: reusable ADR template consistent with the newly accepted scraper domain ADR

- [ ] **Step 1: Write the failing template regression test**

```ruby
test "adr template includes alternatives and related tickets sections" do
  template = Rails.root.join(".ai/templates/adr.md").read

  assert_includes template, "## Alternatives Considered"
  assert_includes template, "## Related Tickets"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL because the current template is too small

- [ ] **Step 3: Write the minimal improved ADR template**

```markdown
# ADR: <title>

## Status
Proposed / Accepted / Superseded

## Context
<why this decision exists>

## Decision
<what was decided>

## Alternatives Considered
- <alternative>

## Consequences
- <impact>

## Related Tickets
- <ticket>
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: PASS


### Task 3: Update project status to reflect Ticket 007 completion

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/.ai/STATUS.md`
- Test: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: Task 1 ADR outcome
- Produces: current status file that points future work toward Tickets 008/009 using the new ADR baseline

- [ ] **Step 1: Write the failing status regression test**

```ruby
test "status mentions scraper domain ADR completion" do
  status = Rails.root.join(".ai/STATUS.md").read

  assert_includes status, "Scraper domain ADR defined"
  assert_includes status, "Execute Ticket 008 or 009"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: FAIL because current status does not mention Ticket 007 completion

- [ ] **Step 3: Update `.ai/STATUS.md` minimally**

```markdown
# Status

## Current Phase
Bootstrap complete

## Current Task
Awaiting next scraper implementation ticket

## Status
Done

## Done
- Docs and tickets created
- Rails app initialized
- Core models added
- Mock scraper pipeline added
- Initial portal added
- Scraper domain ADR defined

## Doing
- None

## Blockers
- None

## Risks
- Real source adapters and notification delivery still require careful escalation

## Human Input Needed
- Choose next implementation ticket

## Next Step
Execute Ticket 008 or 009 using the scraper domain ADR as the baseline
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: PASS


### Task 4: Run full verification for the documentation changes

**Files:**
- Modify: `/Users/fededallo/Desktop/rental-scout-lite/test/config/bootstrap_config_test.rb`

**Interfaces:**
- Consumes: Tasks 1-3 documentation changes
- Produces: a fully verified Ticket 007 documentation baseline

- [ ] **Step 1: Run the full focused config test file**

Run: `bin/rails test test/config/bootstrap_config_test.rb`
Expected: PASS

- [ ] **Step 2: Run full suite and autoloading check**

Run: `bin/rails test && bin/rails zeitwerk:check`
Expected: all tests pass and Zeitwerk reports `All is good!`

- [ ] **Step 3: Commit the Ticket 007 documentation work**

```bash
git add .ai/decisions/adr-scraper-domain.md .ai/templates/adr.md .ai/STATUS.md test/config/bootstrap_config_test.rb
git commit -m "docs: define scraper domain ADR"
```

## Self-Review

### Spec coverage
- Records `../home_scraper` as scraper-loop reference: Task 1.
- Records `../scraper` as app/domain inspiration: Task 1.
- Defines domain entities, dedup rules, new-listing meaning, and notification idempotency: Task 1.
- Marks provisional areas explicitly: Task 1.
- Makes project ADR tooling consistent with that structure: Task 2.
- Updates project status to point future work at 008/009 from the ADR baseline: Task 3.

### Placeholder scan
- Template placeholders remain only in the reusable ADR template, where they are intentional.
- Implementation steps contain concrete file paths, content, and commands.

### Type consistency
- The plan consistently refers to `.ai/decisions/adr-scraper-domain.md` as the primary artifact.
- Entity names (`Listing`, `ListingSource`, `ScrapingRun`, `ScrapingSourceRun`, `SeenListing`, `NotificationEvent`) are used consistently across tasks.
