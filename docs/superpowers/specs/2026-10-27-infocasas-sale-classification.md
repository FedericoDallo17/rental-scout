# InfoCasas sale classification

InfoCasas operation ID 1 must normalize to `venta` and ID 2 to `alquiler`, including string IDs. Explicit unknown IDs must stay out of scope rather than inherit the requested operation. When the ID is absent, only an exact legacy URL segment `venta` or `alquiler` may override the requested operation; descriptive slugs and `/proyectos/` are not operations.

Validate with HTTP-boundary regression tests and exactly one sale index HTTP request per active real provider (no pagination, detail requests, database writes or notifications). Replay those captured responses offline through the public adapters. Push after verification. Existing invalid inventory is not blindly relabeled; recovery requires source verification.
