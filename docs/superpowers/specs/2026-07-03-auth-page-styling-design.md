# Auth Page Styling Design

## Context
The app now has working Devise-based authentication with a sign-in-first entry flow, but the current auth pages still use near-default Devise markup and minimal layout styling. Functionally they work, but visually they feel disconnected from the rest of the product.

The authenticated listings app already has a warm neutral palette, soft surfaces, rounded cards, and a more deliberate visual hierarchy. The auth experience should feel like part of the same product family while remaining more focused and premium than the main listings UI.

The user-approved direction is:
- no pre-auth marketing surface
- root stays sign-in-first
- use a more polished SaaS-style auth presentation
- keep this pass presentation-only

## Goals
- Create a dedicated auth shell that feels intentional rather than scaffolded.
- Make sign in and sign up visually consistent with the app’s brand palette.
- Improve form hierarchy, spacing, and button/input styling.
- Style shared auth links and error states so the whole flow feels cohesive.
- Optionally bring password reset pages into the same shell if they are touched in the same pass.

## Non-Goals
- Changing authentication behavior or routing.
- Redesigning the authenticated listings app.
- Adding illustrations, large marketing panels, or feature previews.
- Adding new fields, validations, or auth flows.
- Introducing a separate public landing page.

## Approaches Considered

### 1. Polished centered auth shell
**Recommendation.**

Use a centered full-page auth layout with a single elevated card, stronger typography, and refined form controls.

Pros:
- Best balance between premium feel and implementation scope.
- Fits the app’s auth-first private-tool posture.
- Works cleanly for sign in, sign up, and password reset.
- Avoids unnecessary layout complexity.

Cons:
- Less visually dramatic than a split-screen SaaS layout.

### 2. Split-screen auth layout
Use a two-column layout with brand/value copy on one side and the form on the other.

Pros:
- Feels more overtly “SaaS”.
- Creates more room for visual personality.

Cons:
- Introduces more layout complexity than needed.
- Pushes toward marketing content the user explicitly does not want.
- Harder to keep elegant at smaller sizes.

### 3. Ultra-minimal elevated form
Use a mostly bare, high-quality form card with very little supporting text.

Pros:
- Clean and tightly scoped.
- Strong fit for a private-tool product.

Cons:
- Risks feeling generic.
- Leaves less room for product identity.

## Decision
Adopt a polished centered auth shell.

## Design

### Auth shell structure
The auth experience should use a dedicated shell rather than raw page-level form markup.

The shared shell should provide:
- a full-page centered layout
- a restrained branded eyebrow or product label
- one elevated auth card
- a title area for the current auth page
- room for supporting copy, form content, flash messages, and shared links

This shell should be reusable across:
- sign in
- sign up
- password reset pages, if included in the styling pass

### Visual direction
The auth pages should stay in the same visual family as the listings app, but be more focused and premium.

That means:
- keep the warm neutral palette
- keep soft backgrounds and rounded surfaces
- increase whitespace and reduce clutter
- use stronger type hierarchy for page titles and field labels
- make the form card feel high contrast and calm

The result should feel like a product entry flow, not a generated admin form.

### Form styling
Form controls should be upgraded from raw default browser presentation into a consistent auth system.

Expected treatment:
- vertically stacked fields with consistent spacing
- modern rounded inputs with comfortable height
- visible focus states aligned to the brand palette
- one prominent primary submit button
- quieter secondary links below the main action
- clear inline error and flash styling

Checkboxes such as “remember me” should be aligned and styled so they do not break the visual rhythm of the form.

### Shared layout behavior
The global layout should distinguish between:
- authenticated app pages
- unauthenticated auth pages

Auth pages should not reuse the same simple top navigation presentation currently shown to guests. Instead, they should use the dedicated auth shell.

Authenticated pages should keep their current app-oriented structure.

This separation should be implemented in a way that keeps responsibilities clear:
- shared page chrome logic in the application layout
- auth page-specific structure in a reusable partial or layout fragment
- page-specific forms remaining inside Devise views

### Scope of pages touched
This styling pass must include:
- sign in
- sign up
- shared Devise links
- error message presentation

It may also include:
- password reset request page
- password reset edit page

Including password reset is recommended if it can be done with the same auth shell and without adding significant complexity, because it prevents one part of the auth flow from feeling unfinished.

## Testing Strategy

### 1. Integration coverage for auth pages
Update or add tests that verify:
- sign in still renders successfully
- sign up still renders successfully
- the signup page still includes the custom user fields
- auth pages render the shared shell markers or expected key text

### 2. Auth flow regression coverage
Preserve coverage proving that:
- registration still works
- sign in still works
- sign out still works
- guest redirects still behave correctly

### 3. Optional password reset coverage
If password reset pages are restyled, ensure there is at least minimal rendering coverage so the shared shell changes do not accidentally break those routes.

## Risks and Mitigations
- **Risk:** Styling work accidentally alters auth behavior.
  - **Mitigation:** Keep this pass presentation-only and preserve existing auth flow tests.
- **Risk:** The auth shell diverges too far from the rest of the app.
  - **Mitigation:** Reuse the existing palette, rounded surfaces, and spacing language.
- **Risk:** Devise view overrides become messy or repetitive.
  - **Mitigation:** Centralize shared auth-shell structure and shared styles instead of duplicating markup across pages.
- **Risk:** Password reset feels inconsistent if omitted.
  - **Mitigation:** Include it if the shared shell applies cleanly with low additional complexity.

## Related Files
- `app/views/layouts/application.html.erb`
- `app/views/devise/sessions/new.html.erb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/shared/_links.html.erb`
- `app/views/devise/shared/_error_messages.html.erb`
- `app/views/devise/passwords/new.html.erb`
- `app/views/devise/passwords/edit.html.erb`
- `app/assets/stylesheets/application.css`
