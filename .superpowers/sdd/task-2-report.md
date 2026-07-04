Status: DONE

Files changed:
- app/services/sources/info_casas_api_adapter.rb
- test/services/sources/info_casas_api_adapter_test.rb
- .superpowers/sdd/task-2-report.md

Test commands run and outputs:

1. `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 57226

# Running:

E

Error:
Sources::InfoCasasApiAdapterTest#test_fetch_listings_normalizes_the_legacy_info_casas_payload_into_listing_intake_attributes:
NameError: uninitialized constant Sources::InfoCasasApiAdapterTest::Net
    test/services/sources/info_casas_api_adapter_test.rb:8:in `block in <class:InfoCasasApiAdapterTest>'

bin/rails test test/services/sources/info_casas_api_adapter_test.rb:4



Finished in 0.013844s, 72.2335 runs/s, 0.0000 assertions/s.
1 runs, 0 assertions, 0 failures, 1 errors, 0 skips
```

2. `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 13846

# Running:

E

Error:
Sources::InfoCasasApiAdapterTest#test_fetch_listings_normalizes_the_legacy_info_casas_payload_into_listing_intake_attributes:
NoMethodError: undefined method `stub' for class Net::HTTP
    test/services/sources/info_casas_api_adapter_test.rb:9:in `block in <class:InfoCasasApiAdapterTest>'

bin/rails test test/services/sources/info_casas_api_adapter_test.rb:5



Finished in 0.016113s, 62.0617 runs/s, 0.0000 assertions/s.
1 runs, 0 assertions, 0 failures, 1 errors, 0 skips
```

3. `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 64268

# Running:

F

Failure:
Sources::InfoCasasApiAdapterTest#test_fetch_listings_normalizes_the_legacy_info_casas_payload_into_listing_intake_attributes [test/services/sources/info_casas_api_adapter_test.rb:17]:
Expected: 1
  Actual: 0

bin/rails test test/services/sources/info_casas_api_adapter_test.rb:5



Finished in 0.011229s, 89.0551 runs/s, 89.0551 assertions/s.
1 runs, 1 assertions, 1 failures, 0 errors, 0 skips
```

4. `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 12649

# Running:

.

Finished in 0.011688s, 85.5578 runs/s, 171.1157 assertions/s.
1 runs, 2 assertions, 0 failures, 0 errors, 0 skips
```

5. `bin/rails test test/services/sources/adapter_registry_test.rb test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 64109

# Running:

..

Finished in 0.026862s, 74.4546 runs/s, 111.6819 assertions/s.
2 runs, 3 assertions, 0 failures, 0 errors, 0 skips
```

6. `bin/rails test test/services/sources/adapter_registry_test.rb test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 64869

# Running:

..

Finished in 0.030426s, 65.7333 runs/s, 98.5999 assertions/s.
2 runs, 3 assertions, 0 failures, 0 errors, 0 skips
```

Git commit(s) created:
- 7f9f2daf71c912cea1ea9b2cf6ca68e79914fa16 `feat: add info casas api adapter`

Concerns / self-review notes:
- The brief's `Net::HTTP.stub` setup was not supported in this test environment, so the test uses a temporary singleton-method override to reach the intended red state without changing production behavior.
- I intentionally did not touch Task 3 or the existing orchestration/intake flow.

---

Task 2 review-fix follow-up

Status: DONE

Files changed:
- app/services/sources/info_casas_api_adapter.rb
- test/services/sources/info_casas_api_adapter_test.rb
- .superpowers/sdd/task-2-report.md

Test commands run and outputs:

1. `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 62937

# Running:

F

Failure:
Sources::InfoCasasApiAdapterTest#test_fetch_listings_raises_when_the_payload_is_malformed [test/services/sources/info_casas_api_adapter_test.rb:42]:
NoMethodError expected but nothing was raised.

bin/rails test test/services/sources/info_casas_api_adapter_test.rb:38

.

Finished in 0.015830s, 126.3424 runs/s, 189.5136 assertions/s.
2 runs, 3 assertions, 1 failures, 0 errors, 0 skips
```

2. `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 2 tests in a single process (parallelization threshold is 50)
Run options: --seed 47032

# Running:

..

Finished in 0.016903s, 118.3222 runs/s, 177.4833 assertions/s.
2 runs, 3 assertions, 0 failures, 0 errors, 0 skips
```

3. `bin/rails test test/services/sources/adapter_registry_test.rb test/services/sources/info_casas_api_adapter_test.rb`

```text
Running 3 tests in a single process (parallelization threshold is 50)
Run options: --seed 12521

# Running:

...

Finished in 0.048980s, 61.2495 runs/s, 81.6660 assertions/s.
3 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Git commit(s) created:
- 7bc0c204f43f2aed5584de43be6c58dc9efc5be8 `fix: tighten info casas adapter error handling`

Notes:
- Removed `.to_a` from `payload.dig(...).map` so malformed InfoCasas API payloads raise naturally instead of silently becoming an empty listing array.
- Replaced the class-level `Net::HTTP.start` monkey-patch in the adapter test with an adapter-scoped `http_response` singleton override to keep test isolation narrower without changing the production flow.
- Kept the existing orchestration and intake flow unchanged and did not work on Task 3.
