# Workflow Guardrails Handoff

## Status
Guardrail changes are **applied to the working tree but uncommitted**. They do not
overlap with the in-flight Ticket 014 changes also present in the tree, so they can
be committed as a clean, separate `test:`/`docs:` pair. `bin/rails test` is green
(105 runs, 0 failures) with everything below applied.

## Premise
The doc scaffolding (`CLAUDE.md`, `.ai/STATUS.md`, ADRs, tickets, governance) was
already complete. The gap was **enforcement, not more documents** — every past
failure (functionally dead backfill, intermingled uncommitted changes, empty demo
feed) happened despite the conventions being written down. This pass converts
gotchas into mechanisms (tests, template fields, settings) and deliberately avoids
adding more role/process prose. The pattern being trusted: gotcha → rule →
**mechanism**.

## Changes made (applied, uncommitted)

1. **`test/assets/stylesheet_mirror_test.rb`** (NEW) — asserts
   `public/stylesheets/application.css` is byte-identical to
   `app/assets/stylesheets/application.css`. Enforces the no-Propshaft mirror rule
   that was previously only a sentence in `CLAUDE.md`. Currently green (files
   identical).

2. **`test/config/bootstrap_config_test.rb`** (REWRITTEN) — **this test was already
   failing before the pass started.** It asserted `.ai/STATUS.md` matched a frozen
   June bootstrap snapshot verbatim, so it broke the moment STATUS was legitimately
   updated in the 07-06 audit. Replaced the exact-match assertion with a structural
   one: STATUS must contain its 10 section headers (`# Status`, `## Current Phase`,
   `## Current Task`, `## Status`, `## Done`, `## Doing`, `## Blockers`, `## Risks`,
   `## Human Input Needed`, `## Next Step`). Removed the dead
   `expected_status_baseline` helper. This lets STATUS live and change while keeping
   its schema stable.

3. **`.ai/templates/ticket.md`** — added a **Definition of Done** checklist after
   "Human Approval Required?": tests green / STATUS updated / ADR if architectural /
   spec+plan committed / superseded docs marked. This is the "backward-pressure
   rule" (CLAUDE.md's self-described known weakness) as a template field instead of
   prose.

4. **`.claude/settings.json`** (NEW, checked in — distinct from the gitignored
   `settings.local.json`) — allowlists the safe loop (`bin/rails test`,
   `bin/rubocop`, `bin/setup`, read-only git) and puts `bin/jobs` and
   `bin/rails runner` behind `ask` (the two easiest ways to accidentally trigger a
   live scrape).

5. **`.ai/docs/testing_policy.md`** — hardened the adapter rule from "fixture-driven
   when practical" to: **stub at the HTTP layer (WebMock), never stub
   `fetch_listings` wholesale**, citing the dead-backfill incident as the reason.

6. **`CLAUDE.md`** — three edits: (a) mirror rule now cites its enforcing test;
   (b) "don't run scrape loops casually" → **"never trigger a live scrape unless the
   user explicitly asks in this session"**; (c) added a session-exit rule: end with
   commits at ticket boundaries or a dated note in `docs/superpowers/handoffs/`,
   never unlabeled work in the tree.

7. **`.ai/STATUS.md`** — Done section records this guardrail work.

## Decisions to preserve (do not re-litigate)

- **Rejected: more role/process docs.** `AGENTS.md`'s 7-role taxonomy is already
  more structure than the loop uses in practice. Extending it is documentation
  theater.
- **Deferred deliberately: the end-to-end verification runbook** (safely validating
  one bounded live InfoCasas scrape cycle — how to trigger a single run, what to
  check in `scraping_runs` / `listings` / `seen_listings`, how to confirm the demo
  feed populates). Should be written **during** Ticket 014, when a live cycle is
  actually run. Writing it before anyone has executed one would repeat the
  dead-backfill anti-pattern (a procedure that looks right but was never exercised).
- **Rejected: a `SCRAPE_LIVE=1` env guard.** No such code guard exists yet;
  documenting imaginary enforcement is worse than stating policy. The code-level
  guard belongs in Ticket 014's rate-limiting work.

## Next steps

1. **Commit the guardrails** as their own `test:`/`docs:` pair, separate from the
   Ticket 014 work. Suggested split:
   - `test: enforce stylesheet mirror and STATUS structure` — the two test files.
   - `docs: add workflow guardrails (DoD, live-scrape rail, HTTP-stub rule, settings)`
     — `CLAUDE.md`, `.ai/templates/ticket.md`, `.ai/docs/testing_policy.md`,
     `.claude/settings.json`, `.ai/STATUS.md`, this handoff.
2. **Resolve the tree's session-exit-rule violation.** The tree currently holds
   three change sets (guardrails, Ticket 014 in-flight, backfill job/service)
   uncommitted — which the new rule outlaws. After committing the guardrails, land
   or explicitly hand off Ticket 014.
3. **Optional (2 min):** backfill the Definition of Done checklist into existing
   tickets 014–016, which predate it.
4. **Next session should be ticket work (Ticket 014), not more workflow work.** The
   honest test of these guardrails is running 014 through the full loop
   (spec → plan → implement → DoD → STATUS → commit). Wherever that run creaks is
   the next real refinement — grounded in an actual failure, not a predicted one.
   Write the E2E verification runbook (deferred item above) as part of that run.
