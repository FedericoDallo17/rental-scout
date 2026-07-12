# Notification Settings Design

## Goal

Close the configuration gap between the working notification pipeline and the user
interface with a small authenticated account settings surface.

## Experience

The app header links to "Notifications." The page shows whether a Pushover key is
configured and offers an empty password-style field for a replacement. The stored
key is never used as an input value or printed in masked form; even partial key
disclosure is unnecessary. Submitting the field blank preserves the current key.
An explicit checkbox removes it.

## Security

- The controller always updates `current_user`; there is no user ID in the route.
- Only `pushover_user_key` and the removal flag are accepted.
- The existing `_key` parameter filter covers `pushover_user_key`; a regression test
  makes that behavior explicit.
- Success messages report configuration state without including the key.
- Saving settings never sends a notification or validates against Pushover.

## Non-goals

- Pushover API-token management
- Sending test notifications
- Provider credentials
- Encrypting the existing database column (requires a separate migration decision)
