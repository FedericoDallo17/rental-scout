# Password recovery delivery repair

Production recovery POSTs fail with ECONNREFUSED against localhost:25. SMTP is
not configured, Devise ignores MAIL_FROM, and recovery mail is English-only.

Use authenticated TLS SMTP (Resend Free selected by the user), one configured
sender for all mail, and the saved account locale. Failures must show a useful
retry message without claiming success or exposing SMTP responses. Until
credentials/domain verification exist, delivery must fail explicitly while the
rest of the application remains available. Do not change password/token rules,
enable unrelated notifications, or modify the database schema.

Verification: configuration tests, complete email/link/password/login lifecycle,
expired and replayed tokens, both languages, missing-provider and refused-SMTP
responses, full existing suite, immutable deployment and production smoke checks.
