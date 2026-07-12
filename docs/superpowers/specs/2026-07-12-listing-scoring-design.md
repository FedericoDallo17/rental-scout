# Listing Scoring Design

## Goal

Rank the already-matching listings in a saved-search feed so the strongest matches
surface first, while keeping freshness as the tie-breaker.

## Scope

- Compute a transient 0–100 score for each listing against the active saved search.
- Score price fit (60 points), bedroom fit (25 points), and listing detail
  completeness (15 points).
- Show the score and a short, plain-language explanation on each listing card.
- Sort by score descending, then by listing creation time descending.
- Do not persist scores: they are specific to a saved search and inexpensive to
  calculate for the deliberately small, freshness-first inventory.

## Rules

### Price fit (0–60)

- With a maximum price, listings at or below 75% of the maximum receive 60 points.
- Between 75% and 100%, points decrease linearly from 60 to 0.
- Without a maximum price, price contributes a neutral 30 points.

### Bedroom fit (0–25)

- With a minimum, meeting it earns 20 points and each additional bedroom earns 5,
  capped at 25.
- Without a minimum, bedrooms contribute a neutral 12 points.

### Detail completeness (0–15)

Three points each are awarded for a known price, square meters, expenses, parking,
and property type. Zero is considered a known value for expenses and parking.

## Explanation

The card exposes up to three compact facts: budget position, bedroom fit, and
detail completeness. The explanation describes inputs; it does not claim that the
score predicts quality.

## Non-goals

- User-configurable weights
- Persisted scores or a database migration
- Cross-currency conversion
- Changing feed eligibility or notification matching
- Reintroducing the map UI
