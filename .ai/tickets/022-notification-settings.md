# Ticket: 022 - Notification Settings

## Goal

Let an authenticated user configure or remove the Pushover user key required by the
existing notification pipeline without exposing the saved credential.

## Acceptance Criteria

- [x] Signed-in users can open notification settings from the app header.
- [x] Users can save or explicitly remove their own Pushover key.
- [x] Existing keys are never rendered back into HTML; a blank submission preserves them.
- [x] The key parameter is filtered from logs.
- [x] Guests cannot access or update settings.

## Human Approval Required?

Yes. This is security-sensitive credential handling; approved by the user on
2026-07-12 before implementation.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] Spec/plan committed alongside the work
