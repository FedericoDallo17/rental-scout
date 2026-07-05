# Task 3 Report

Status: implemented

Summary:
- Added `Scraping::ListingScopeValidator` to mark Montevideo rentals in scope and attach rejection reasons for out-of-scope listings.
- Wired scope validation into `Scraping::ListingIntake` after geometry normalization and filtered transient adapter fields before persistence.
- Broadened `Sources::InfoCasasApiAdapter` to request Montevideo-wide inventory without legacy map filters and to emit source metadata plus coordinates.

TDD notes:
- Added failing tests in `test/services/scraping/listing_scope_validator_test.rb`.
- Updated adapter tests to expect broad Montevideo request params and normalized source metadata/coordinates.
- Added intake coverage for persisted `in_scope` and `scope_rejection_reason` behavior after normalization.
- Verified red state before implementation with missing service / old adapter shape failures.
- Verified green state after implementation.

Verification:
- Command: `bin/rails test test/services/scraping/listing_scope_validator_test.rb test/services/sources/info_casas_api_adapter_test.rb test/services/scraping/listing_intake_test.rb`
- Result: 18 runs, 64 assertions, 0 failures, 0 errors, 0 skips

Review follow-up:
- Updated `Sources::InfoCasasApiAdapter` to derive `source_city` from provider location text and `operation_type` from the provider listing path instead of hardcoding Montevideo rentals.
- Added regression coverage proving provider payload metadata survives normalization and can drive `Scraping::ListingScopeValidator` to mark leaked out-of-scope records.
- Re-ran `bin/rails test test/services/scraping/listing_scope_validator_test.rb test/services/sources/info_casas_api_adapter_test.rb test/services/scraping/listing_intake_test.rb` with 20 runs, 68 assertions, 0 failures, 0 errors, 0 skips.

Files changed:
- `app/services/scraping/listing_scope_validator.rb`
- `app/services/scraping/listing_intake.rb`
- `app/services/sources/info_casas_api_adapter.rb`
- `test/services/scraping/listing_scope_validator_test.rb`
- `test/services/sources/info_casas_api_adapter_test.rb`
- `test/services/scraping/listing_intake_test.rb`
