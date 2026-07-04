# Devise Auth Foundation Design

## Context
The app now has working listing and scraper foundations, but it still has no notion of a signed-in user. That blocks the next stage of the product, because later work needs a clear current-user boundary before searches, scraper outputs, and notifications can become user-specific.

The current app root is `listings#index`, and there is no authentication gate. The next step should establish account identity and access control without yet changing data ownership.

The user-approved direction is:
- use Devise
- keep the first ticket narrow
- protect everything except auth pages
- defer ownership and user-scoped scraper data until later
- include `first_name` and `last_name` on `User`
- include an optional stored Pushover user key on `User`
- do not show product marketing or previews before authentication
- send unauthenticated users to sign in first

## Goals
- Introduce a `User` model with Devise-backed email/password authentication.
- Store first name and last name on the `User` record.
- Store an optional Pushover user key on the `User` record for later notification work.
- Support sign up, sign in, and sign out.
- Add an authenticated app boundary so product pages require a current user.
- Make the root route send unauthenticated users directly to sign in.
- Preserve current app data as global for now, without attaching listings, searches, or preferences to users yet.

## Non-Goals
- Associating existing domain records with users.
- Making listings, scraper runs, or saved searches user-owned.
- Sending notifications or implementing notification delivery behavior.
- Implementing roles, authorization tiers, or admin behavior.
- Building account settings beyond what Devise requires for the initial auth flow.

## Approaches Considered

### 1. Devise with app-wide authentication gate and sign-in-first root route
**Recommendation.**

Use Devise for user registration and session management, make the root route the sign-in entry point, require authentication everywhere else, and extend the base `User` profile with names plus an optional stored Pushover user key.

Pros:
- Fastest route to a secure and conventional auth foundation.
- Creates a clear product boundary with no pre-auth product surface to maintain.
- Fits the future need for user-scoped scraper outputs and notifications.
- Keeps the current ticket focused on identity and access while still capturing obvious user fields needed soon.

Cons:
- Requires immediate route-flow updates because the current root page is inside the app.
- Makes sign up a secondary path rather than the primary first screen.

### 2. Devise with a narrower initial protected area
Use Devise, but only protect a subset of app pages first.

Pros:
- Smaller immediate surface area.
- Less route churn in the short term.

Cons:
- Creates a temporary split mental model for what is public versus private.
- Would likely need another auth-boundary change soon after.

### 3. Hand-rolled Rails authentication
Build email/password authentication directly with Rails session primitives.

Pros:
- Full implementation control.
- Fewer external abstractions.

Cons:
- More security-sensitive code to own.
- Slower and less aligned with the user’s chosen direction.
- Adds unnecessary implementation risk for a foundation ticket.

## Decision
Implement the first auth ticket with Devise, a sign-in-first root route, an app-wide authentication requirement for non-authenticated product pages, and a slightly richer `User` record containing names plus an optional Pushover user key.

## Design

### Authentication model
The app will use a conventional email/password login model backed by Devise.

The initial `User` record should support:
- unique email
- required first name
- required last name
- optional `pushover_user_key`
- encrypted password
- standard Devise session lifecycle for registration, login, and logout

This ticket only answers:
- who is the current user?
- can they authenticate securely?
- can the app protect private pages consistently?

It does not answer:
- which data belongs to which user
- how favorites behave
- when or how notifications are sent

### User fields and validation
The initial signup flow should collect:
- `first_name`
- `last_name`
- `email`
- `password`
- `password_confirmation`
- `pushover_user_key` (optional)

Validation should be intentionally light:
- `email` is required and unique through Devise
- `first_name` is required
- `last_name` is required
- `pushover_user_key` may be blank

This ticket should not add a composite index on `first_name` and `last_name`, because names are not an intended lookup path in the current app.

This ticket should also avoid adding strict format validation or uniqueness rules to `pushover_user_key`, because notification behavior is still out of scope.

### Access model
Guest users can access:
- Devise authentication pages such as sign in and sign up

Authenticated users can access:
- the rest of the application

If a guest requests a protected page, they should be redirected to sign in.

The app should centralize this behavior in `ApplicationController`, using an authenticated-by-default posture with explicit exceptions only for Devise-managed routes.

### Route and page structure
Because the current root route points to `listings#index`, this ticket should move the current app experience behind authentication and make the root route resolve to sign in for guests.

Expected route structure:
- guest root route: sign in page
- Devise routes: registration and session pages
- authenticated app pages: listings and other product pages

This app should behave like a private tool rather than a public marketing site at this stage. Sign up remains available, but it is reached from the auth flow rather than from a standalone public landing page.

### Registration form impact
Because the user record now includes required names and an optional Pushover user key, the registration flow should permit and persist those extra attributes.

That means this ticket should include the minimal Devise parameter customization needed to:
- accept `first_name`
- accept `last_name`
- accept `pushover_user_key`

The login flow should remain email/password only.

### Root behavior
Unauthenticated users visiting `/` should land on sign in.

Authenticated users visiting `/` should be redirected into the main authenticated app surface.

This keeps the root route useful for both states without adding a separate guest page.

### Scope boundary around ownership
This ticket deliberately separates authentication from ownership.

After implementation:
- users can sign in
- private app pages know who the current user is
- existing listings and scraper data remain global

That means later ownership work can be introduced as a separate change that re-scopes data models and queries without needing to redesign the auth layer.

### Devise customization level
Use standard Devise behavior unless the current app needs small view or redirect customization to fit the routing structure and the extra registration fields.

Custom Devise views should only be generated if needed for:
- links and layout consistency
- collecting first and last name plus optional Pushover user key at signup
- minimal UX fit with the existing app

No extra custom account flows should be added in this ticket.

## Testing Strategy

### 1. Authentication flow coverage
Add tests that verify:
- a user can register with first name, last name, email, and password
- a user can sign in with valid credentials
- invalid credentials are rejected
- a signed-in user can sign out

### 2. Access control coverage
Add tests that verify:
- guests can access auth pages
- guests hitting `/` are taken to sign in
- guests are redirected from protected app pages to sign in
- signed-in users can access protected pages

### 3. User model and persistence coverage
Add coverage proving:
- email uniqueness is enforced
- first name is required
- last name is required
- optional `pushover_user_key` persists when provided
- passwords are not stored in plain text
- Devise-backed authentication persists usable session state across requests in the normal app flow

## Risks and Mitigations
- **Risk:** The auth ticket grows into ownership migration.
  - **Mitigation:** Keep all data-association changes out of scope and document them as follow-up work.
- **Risk:** Existing root-page behavior becomes confusing during the transition.
  - **Mitigation:** Make `/` explicitly auth-first for guests and authenticated-app-first for signed-in users.
- **Risk:** Over-customizing Devise increases implementation surface area.
  - **Mitigation:** Prefer default Devise behavior and only customize where routing, signup fields, or minimal UX requires it.
- **Risk:** Optional notification identity gets mistaken for active notification support.
  - **Mitigation:** Treat `pushover_user_key` as stored profile data only and keep all notification behavior out of scope.

## Sequencing
Recommended next order after this ticket:
1. Auth foundation with Devise
2. User ownership of product data
3. User-aware scraper outputs and downstream matching/notification work

This preserves the intended dependency chain:
- identity before ownership
- ownership before personalized scraper and notification behavior

## Related Files
- `docs/superpowers/specs/2026-06-29-user-auth-ticket-design.md`
- `config/routes.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/`
- `app/views/`
- `Gemfile`
