# Ticket 032: Preference Fit Score

The current score combines price, bedrooms, neutral points for unspecified
preferences, and listing completeness. As a result, a broad search can show a number
that looks like measured preference fit even though no preference was evaluated.

The replacement score evaluates only active maximum-price and minimum-bedroom
preferences. With both present, normalized price fit carries 70% and bedroom fit 30%.
With only one present, that component fills the 0–100 scale. Existing component
curves remain unchanged: price rewards headroom below the maximum, and bedrooms
reward meeting or exceeding the minimum. Cross-currency prices score zero and retain
their explicit explanation.

When neither preference is active, `score` is nil and the card omits the number.
Provider detail completeness becomes a separate localized label. The UI calls the
number “fit”/“afinidad” and uses a dark green with sufficient contrast on white.

