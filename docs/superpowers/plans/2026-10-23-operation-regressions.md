# Operation regression plan

1. Reproduce the queued notification and sidebar failures.
2. Add HTTP-stubbed Remax checks for mismatched query/result operations, sale
   normalization, absent metadata fallback and unknown explicit operations.
3. Normalize provider metadata before request fallback; update sidebar expectation.
4. Run targeted regressions and complete Rails suite; document validation.
5. Review/stage related product changes separately from generated local artifacts,
   create focused commits and push the resulting verified branch.
