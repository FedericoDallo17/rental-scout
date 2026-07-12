# Conservative Cross-Source Dedup Plan

1. Add intake tests for an exact cross-source match and a differing signature.
2. Add a secondary conservative identity lookup after source-local lookup.
3. Preserve the representative listing and record the second source occurrence.
4. Record the identity decision in an ADR and update project state.
5. Run the full suite and commit the ticket.
