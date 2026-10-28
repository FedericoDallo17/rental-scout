# Password recovery repair plan

1. Isolate PostGIS test databases and cover the full recovery flow.
2. Add TLS SMTP configuration and explicit unavailable-provider delivery.
3. Unify senders, localize recovery mail, handle delivery errors in recovery POST.
4. Test SMTP options, successful reset/login, expired/reused tokens and outages.
5. Run the full suite, document setup and deploy through the existing Actions flow.
6. Configure Resend credentials/domain DNS when supplied; verify actual delivery
   only to an explicitly authorized recipient. Report any remaining setup blocker.
