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

The external disk DevOffload is unmounted. Changes are in a temporary clone
at /private/tmp/rental-scout-mail-fix, with an isolated PostGIS test container
timbre-mail-test-db on localhost:55439. Never use that container for production.

Resend is now active. The user created a sending-only API key in macOS Keychain,
service `timbre/resend-api-key`, account `fededallo`. This key cannot administer
domains (Resend returns restricted_api_key); the user added timbre.dallo.dev and
its Cloudflare DNS records. DKIM/SPF/MX resolve publicly. Resend accepted the
production SMTP test after initial domain propagation.

The key is persisted as a Coolify service secret, referenced through environment
variables in both raw/generated Compose definitions for web and job. Never put
the key in source control, shell arguments, tool output or chat. The sender is
`Timbre <notifications@timbre.dallo.dev>`, SMTP is smtp.resend.com:587 with required
STARTTLS. The existing immutable deployment helper recreated both roles and
reported healthy production at e1b7aae55bba9ecaf5bfa136d37d31ca50f52f2f.

Actual production smoke validation used a temporary account in a transaction:
GET reset form, POST recovery with real Turbo Accept headers, accepted SMTP
delivery to Resend's delivered+label@resend.dev simulator, Spanish subject/body,
canonical HTTPS link, password update, consumed token, sign-out and new-password
login all passed. The test account and token were rolled back. Public /up is 200.
This verifies provider acceptance; no claim is made about a personal inbox.
The browser's real Turbo Accept list includes HTML fallback; an artificial
stream-only Accept header is not a supported successful Devise navigation.
