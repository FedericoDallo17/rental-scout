# Password recovery / Resend handoff

The user authorized fixes, adjacent mail-flow review and production deployment,
then selected Resend Free. No provider previously existed. The original failure
was a recovery POST returning 500 from localhost:25 ECONNREFUSED. The deployment
also had MAIL_FROM=notifications@example.com, ignored by Devise's placeholder.

Implemented: authenticated verified TLS SMTP with bounded timeouts, shared sender,
saved-account locale for Devise delivery, bilingual recovery mail, explicit
unconfigured delivery adapter, and localized 503/retry responses on delivery
failure. No false success when the provider is absent. Existing token semantics
are unchanged; no schema change or new gem. Confirmation/change notifications
are disabled; Web Push and Pushover do not depend on SMTP.

Validation: 336 tests, 2136 assertions, no failures/errors/skips; production asset
precompilation and git diff --check pass. New tests cover configuration, full
recovery/email/link/reset/login lifecycle, expiration/replay, locale and outages.

The external disk DevOffload is unmounted. Changes are in a clean temporary clone
at /private/tmp/rental-scout-mail-fix, with an isolated PostGIS test container
timbre-mail-test-db on localhost:55439. Never use that container for production.

Resend setup remains dependent on the user's new account/key and DNS records.
The user was asked to save the key in /private/tmp/timbre-resend-api-key, without
posting it in chat. See docs/production-deployment.md for exact runtime settings.
Do not configure SMTP_ADDRESS before all credentials are available; an explicit
SMTP server with missing credentials fails boot. The provider-free deployment
keeps the app available and presents a retry message, but cannot deliver mail.
