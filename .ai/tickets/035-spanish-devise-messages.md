# Ticket: 035 - Spanish Devise Messages

## Goal

Ensure authentication notices and errors render in Spanish for users whose saved
language preference is Spanish, without exposing missing-translation diagnostics.

## Acceptance Criteria

- Spanish Devise session notices render translated text.
- The complete Devise message namespace has Spanish coverage for current and future auth flows.
- An integration test exercises a real Spanish-user sign-in redirect and flash.

## Human Approval

Requested directly by the user on 2026-07-14 after observing the missing sign-in translation.

## Definition of Done

- [x] Authentication integration test green
- [x] Full Rails test suite green
- [x] Status and roadmap updated
