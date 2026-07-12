# Conservative Cross-Source Dedup Design

Keep source-local external-ID and canonical-URL lookup as the primary identity path.
When it misses, compare complete conservative signatures across other sources:
case/whitespace-normalized title, price, currency, and bedrooms. Reuse the original
listing without overwriting its provider fields, while attaching the new source's
`SeenListing`. Incomplete and near-matching signatures remain distinct.
