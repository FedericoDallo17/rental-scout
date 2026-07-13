# Ticket 029: InfoCasas Price Currency

InfoCasas exposes rent and common-expense currency separately. The adapter currently
discards that distinction by hardcoding rent to UYU, and its request sends
`currencyID: 2`, which limits acquisition to UYU listings.

The adapter will normalize the provider's visible rent symbol: `$` and `UY$` become
`UYU`; `U$S`, `US$`, and `USD` become `USD`. Unknown or absent values remain unknown
instead of being invented. Common expenses remain `UYU`, matching the provider's
contract and UI. `currencyID` becomes nil so recent Montevideo acquisition covers
both currencies.

This change does not perform conversion. Existing saved-search price bounds remain
UYU-only, so USD listings appear only for searches without price bounds until users
can choose a search currency.

