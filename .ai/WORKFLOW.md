# How to continue this project

This is the loop. Follow it in order. It exists so a new agent can pick up the
project without anyone re-explaining the process. Each step links to the detail;
don't restate those docs, just do what they say.

## 1. Orient (before touching anything)

Read, in this order:

1. `.ai/STATUS.md` — the single source of truth for current state and next step.
2. `.ai/product/roadmap.md` — the **"Now"** item is the ticket you work; "Next" and
   "Later" are not yours to start.
3. The plan for that ticket in `docs/superpowers/plans/` (linked from the roadmap).
4. `.ai/decisions/` — ADRs are settled. **Do not re-litigate them.**
5. The newest note in `docs/superpowers/handoffs/` if one exists — it says what's
   in flight and what's known broken.

Also skim `CLAUDE.md` for the architecture paragraph and the gotchas.

## 2. Work exactly one ticket

- One ticket at a time. Keep it small enough to implement and review independently.
- Dev order: **spec → plan → implement.** Spec lives in
  `docs/superpowers/specs/`, plan in `docs/superpowers/plans/`. If the "Now" ticket
  already has a plan, start from it.
- Implement test-first (TDD). `bin/rails test` is ~2s — keep it green the whole way.
- **Stub adapters at the HTTP layer (WebMock), never stub `fetch_listings`
  wholesale** — wholesale stubs once hid a functionally dead backfill behind a green
  suite (`.ai/docs/testing_policy.md`).

## 3. Escalate at the gates — don't decide unilaterally

Stop and ask the human when you hit anything in `.ai/docs/escalation_rules.md`: new
migration, new gem, new external source or notification service, architecture change,
possible N+1, duplicate-notification risk, security-sensitive code, questionable
scraping behavior. Agents propose; the human decides (`.ai/GOVERNANCE.md`).

**Never trigger a live scrape** (`RunScrapersJob`, `bin/jobs`, a runner calling an
adapter) unless the user explicitly asks for one in this session. The live API
(InfoCasas) has timeouts but no rate limiting yet (Ticket 014).

## 4. Close the loop (Definition of Done)

Before calling a ticket done, satisfy the checklist in `.ai/templates/ticket.md`:

- [ ] `bin/rails test` green
- [ ] `.ai/STATUS.md` updated to reflect the new reality
- [ ] ADR recorded in `.ai/decisions/` if the change is architectural
- [ ] Spec/plan committed alongside the code
- [ ] Superseded docs marked (not deleted, not abandoned)

This is the **backward-pressure rule** — the loop's known weakness. The docs decay
the moment you skip it, so it's enforced by the checklist and by tests
(`test/config/bootstrap_config_test.rb` guards STATUS structure;
`test/assets/stylesheet_mirror_test.rb` guards the CSS mirror).

## 5. End the session cleanly

Never leave unlabeled work in the tree. End with **either**:

- commits at ticket boundaries (conventional commits: `feat:`/`fix:`/`docs:`/`test:`),
  **or**
- a dated note in `docs/superpowers/handoffs/` saying what's in flight and what's
  known broken.

If the tree holds unrelated change sets, commit them separately — don't fold
unrelated work into one commit.

## The shape in one line

Orient (STATUS → roadmap → plan → ADRs) → one ticket, spec→plan→implement TDD →
escalate at the gates → Definition of Done → commit or handoff.
