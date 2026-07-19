# Ticket 036 implementation plan

1. Add admin authorization, role management, operational routes, and separate user run history.
2. Add guarded maintenance controls and move source activation into the admin namespace.
3. Instrument adapter HTTP requests and persist lifetime and per-run request counts.
4. Persist and display hourly versus reconciliation run type.
5. Verify recurring configuration structurally and cover admin access and maintenance behavior.
6. Run migrations and the full test suite, then update status and roadmap.
