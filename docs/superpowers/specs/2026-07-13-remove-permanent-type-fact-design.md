# Ticket 031: Remove Permanent Type Fact

The Type fact consumes permanent card space even though providers often omit it and
the current product is already focused on apartments. Remove the fact from cards
without dropping the underlying `property_type` data. The Source fact spans both
columns in the final facts row, avoiding an unbalanced five-cell grid.

This slice does not introduce conditional badges and does not change the existing
detail-completeness score; both belong to later product decisions.

