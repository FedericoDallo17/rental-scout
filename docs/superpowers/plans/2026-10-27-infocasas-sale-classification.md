# Plan

1. Add failing HTTP-boundary cases for numeric/string IDs, precedence, unknown IDs, absent IDs, descriptive/project URLs and sale query parameters.
2. Correct InfoCasas operation resolution without changing pagination or notification behavior.
3. Run focused and full Rails tests.
4. Capture one sale index response per active provider using the corrected adapter; enforce a request budget and replay responses offline to validate public fetch and intake scope.
5. Record results in STATUS and a handoff, commit and push.
