# Escalation Rules

Ask for human approval when any of the following appear:
- Possible N+1 query.
- New dependency/gem/package.
- New database table or migration.
- Background jobs or retry policy.
- New external source.
- New external notification service.
- Duplicate notification risk.
- Architecture change.
- Security-sensitive code.
- Questionable scraping behavior.

- Escalate when a ticket proposes moving beyond the Rails monorepo default.
- Escalate before enabling any real provider integration; keep each real adapter approval-gated and isolated per adapter.
- Escalate when notification idempotency is unclear or cannot be stated explicitly.
