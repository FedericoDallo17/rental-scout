# Ticket: 027 - Bilingual User Interface

## Goal

Let each user persist an English or Spanish preference and render the signed-in
application in that language.

## Acceptance Criteria

- [x] Existing and new users default to English.
- [x] Signed-in users can switch between English and Spanish from the header.
- [x] The preference persists across requests and does not affect other users.
- [x] Feed, saved searches, runs, notifications, and navigation use I18n translations.
- [x] The document language attribute reflects the active locale.

## Human Approval Required?

Yes. The user requested persisted English/Spanish UI preferences on 2026-07-12.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] No ADR required; locale remains a user-owned presentation preference
- [x] Spec/plan committed alongside the work
- [x] Hardcoded signed-in copy is replaced, not duplicated
