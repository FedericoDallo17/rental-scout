# Auth Page Styling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Devise auth experience with a polished centered auth shell that matches the product’s brand more closely without changing auth behavior.

**Architecture:** Keep routing and auth logic unchanged. Implement the auth polish by adding a reusable auth shell wrapper in the application layout, updating Devise views to expose consistent shell markers and form structure, and extending `application.css` with a dedicated auth design system that leaves the authenticated listings UI intact.

**Tech Stack:** Rails 8.0, ERB, Devise, Minitest, Propshaft CSS

## Global Constraints

- no pre-auth marketing surface
- root stays sign-in-first
- use a more polished SaaS-style auth presentation
- keep this pass presentation-only
- Use TDD: no production code without a failing test first.

---

## File Structure

### Files to modify
- `app/views/layouts/application.html.erb` — switch between authenticated app chrome and unauthenticated auth shell.
- `app/views/devise/sessions/new.html.erb` — add structured sign-in content inside the shared shell.
- `app/views/devise/registrations/new.html.erb` — add structured sign-up content while preserving custom fields.
- `app/views/devise/passwords/new.html.erb` — bring forgot-password into the shared shell.
- `app/views/devise/passwords/edit.html.erb` — bring reset-password into the shared shell.
- `app/views/devise/shared/_links.html.erb` — restyle and group shared secondary links.
- `app/views/devise/shared/_error_messages.html.erb` — add auth-friendly error container markup.
- `app/assets/stylesheets/application.css` — add auth shell, card, form, button, flash, and link styles.
- `test/integration/authentication_flow_test.rb` — add rendering assertions for the shared auth shell and preserve flow tests.

### Files to create
- None required.

## Task 1: Add auth-shell rendering coverage in integration tests

**Files:**
- Modify: `test/integration/authentication_flow_test.rb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: existing Devise routes and current auth pages.
- Produces: failing tests that define the shared auth shell markers and ensure signup fields remain present.

- [ ] **Step 1: Write the failing test**

```ruby
require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "sign in page renders the shared auth shell" do
    get new_user_session_url

    assert_response :success
    assert_select ".auth-shell", count: 1
    assert_select ".auth-card", count: 1
    assert_select ".auth-brand", text: "Rental Scout Lite"
    assert_select ".auth-title", text: "Sign in"
    assert_select ".auth-submit", text: "Sign in"
  end

  test "sign up page renders the auth shell and custom fields" do
    get new_user_registration_url

    assert_response :success
    assert_select ".auth-shell", count: 1
    assert_select ".auth-title", text: "Create account"
    assert_includes response.body, 'name="user[first_name]"'
    assert_includes response.body, 'name="user[last_name]"'
    assert_includes response.body, 'name="user[pushover_user_key]"'
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL because the current auth pages do not render `.auth-shell`, `.auth-card`, `.auth-brand`, `.auth-title`, or `.auth-submit`.

- [ ] **Step 3: Write minimal implementation**

Do not change production code yet; this step is only to record the desired target in tests. Leave the code failing and move directly to Task 2 for the first implementation slice.

- [ ] **Step 4: Run test to verify it still fails for the expected reason**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL with missing auth-shell selectors, not route or template errors.

- [ ] **Step 5: Commit**

```bash
git add test/integration/authentication_flow_test.rb
git commit -m "test: define auth shell rendering"
```

## Task 2: Split authenticated app chrome from unauthenticated auth shell

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: `user_signed_in?`, `current_user`, `flash`, and the failing shell selectors from Task 1.
- Produces: application layout with two branches:
  - authenticated branch keeps app nav/flash and yields existing listings UI
  - unauthenticated branch wraps yielded Devise forms in `.auth-shell` and `.auth-card`

- [ ] **Step 1: Write the failing test refinement**

Add this assertion to `test "sign in page renders the shared auth shell"`:

```ruby
assert_select "header nav", count: 0
```

This proves auth pages no longer reuse the guest top navigation.

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb:12`

Expected: FAIL because the current application layout still renders `header nav` on the sign-in page.

- [ ] **Step 3: Write minimal implementation**

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Rental Scout Lite" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  </head>

  <body class="<%= user_signed_in? ? "app-body" : "auth-body" %>">
    <% if user_signed_in? %>
      <header>
        <nav>
          <span><%= current_user.email %></span>
          <%= button_to "Sign out", destroy_user_session_path, method: :delete %>
        </nav>
      </header>

      <% flash.each do |key, message| %>
        <p class="flash flash--<%= key %>"><%= message %></p>
      <% end %>

      <%= yield %>
    <% else %>
      <main class="auth-shell">
        <section class="auth-card">
          <div class="auth-brand">Rental Scout Lite</div>

          <% flash.each do |key, message| %>
            <p class="flash flash--<%= key %>"><%= message %></p>
          <% end %>

          <%= yield %>
        </section>
      </main>
    <% end %>
  </body>
</html>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb:12`

Expected: PASS for the no-nav assertion while other auth-shell selector tests may still fail until Task 3 updates the forms.

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb test/integration/authentication_flow_test.rb
git commit -m "feat: add auth shell layout"
```

## Task 3: Restructure sign-in and sign-up views to use auth-shell markers

**Files:**
- Modify: `app/views/devise/sessions/new.html.erb`
- Modify: `app/views/devise/registrations/new.html.erb`
- Modify: `app/views/devise/shared/_links.html.erb`
- Modify: `app/views/devise/shared/_error_messages.html.erb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: `.auth-shell` and `.auth-card` wrapper from Task 2.
- Produces: consistent auth-page structure using:
  - `.auth-header`
  - `.auth-title`
  - `.auth-copy`
  - `.auth-form`
  - `.auth-field`
  - `.auth-submit`
  - `.auth-links`
  - `.auth-errors`

- [ ] **Step 1: Write the failing test refinement**

Extend `test "sign in page renders the shared auth shell"` with:

```ruby
assert_select ".auth-header", count: 1
assert_select ".auth-copy", text: /Sign in to continue/
assert_select "form.auth-form", count: 1
assert_select ".auth-links a", text: "Sign up"
assert_select ".auth-links a", text: "Forgot your password?"
```

Extend the sign-up test with:

```ruby
assert_select ".auth-copy", text: /Create your account/
assert_select "form.auth-form", count: 1
assert_select ".auth-links a", text: "Log in"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL because the current Devise views do not yet render the new auth-specific classes or support copy.

- [ ] **Step 3: Write minimal implementation**

```erb
<!-- app/views/devise/sessions/new.html.erb -->
<div class="auth-header">
  <h1 class="auth-title">Sign in</h1>
  <p class="auth-copy">Sign in to continue to your private rental scouting workspace.</p>
</div>

<%= form_for(resource, as: resource_name, url: session_path(resource_name), html: { class: "auth-form" }) do |f| %>
  <div class="auth-field">
    <%= f.label :email %>
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="auth-field">
    <%= f.label :password %>
    <%= f.password_field :password, autocomplete: "current-password" %>
  </div>

  <% if devise_mapping.rememberable? %>
    <label class="auth-checkbox-row">
      <%= f.check_box :remember_me %>
      <span>Remember me</span>
    </label>
  <% end %>

  <%= f.submit "Sign in", class: "auth-submit" %>
<% end %>

<%= render "devise/shared/links" %>
```

```erb
<!-- app/views/devise/registrations/new.html.erb -->
<div class="auth-header">
  <h1 class="auth-title">Create account</h1>
  <p class="auth-copy">Create your account to start tracking rental opportunities privately.</p>
</div>

<%= form_for(resource, as: resource_name, url: registration_path(resource_name), html: { class: "auth-form" }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="auth-field">
    <%= f.label :first_name %>
    <%= f.text_field :first_name, autofocus: true, autocomplete: "given-name" %>
  </div>

  <div class="auth-field">
    <%= f.label :last_name %>
    <%= f.text_field :last_name, autocomplete: "family-name" %>
  </div>

  <div class="auth-field">
    <%= f.label :email %>
    <%= f.email_field :email, autocomplete: "email" %>
  </div>

  <div class="auth-field">
    <div class="auth-field__label-row">
      <%= f.label :password %>
      <% if @minimum_password_length %>
        <span class="auth-hint"><%= @minimum_password_length %> characters minimum</span>
      <% end %>
    </div>
    <%= f.password_field :password, autocomplete: "new-password" %>
  </div>

  <div class="auth-field">
    <%= f.label :password_confirmation %>
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <div class="auth-field">
    <%= f.label :pushover_user_key %>
    <%= f.text_field :pushover_user_key %>
  </div>

  <%= f.submit "Create account", class: "auth-submit" %>
<% end %>

<%= render "devise/shared/links" %>
```

```erb
<!-- app/views/devise/shared/_links.html.erb -->
<div class="auth-links">
  <%- if controller_name != 'sessions' %>
    <p><%= link_to "Log in", new_session_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.registerable? && controller_name != 'registrations' %>
    <p><%= link_to "Sign up", new_registration_path(resource_name) %></p>
  <% end %>

  <%- if devise_mapping.recoverable? && controller_name != 'passwords' && controller_name != 'registrations' %>
    <p><%= link_to "Forgot your password?", new_password_path(resource_name) %></p>
  <% end %>
  
  <%- if devise_mapping.confirmable? && controller_name != 'confirmations' %>
    <p><%= link_to "Didn't receive confirmation instructions?", new_confirmation_path(resource_name) %></p>
  <% end %>
  
  <%- if devise_mapping.lockable? && resource_class.unlock_strategy_enabled?(:email) && controller_name != 'unlocks' %>
    <p><%= link_to "Didn't receive unlock instructions?", new_unlock_path(resource_name) %></p>
  <% end %>
</div>
```

```erb
<!-- app/views/devise/shared/_error_messages.html.erb -->
<% if resource.errors.any? %>
  <div id="error_explanation" class="auth-errors" data-turbo-temporary>
    <h2>
      <%= I18n.t("errors.messages.not_saved", count: resource.errors.count, resource: resource.class.model_name.human.downcase) %>
    </h2>
    <ul>
      <% resource.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: PASS for the auth-shell rendering assertions and existing auth-flow behavior.

- [ ] **Step 5: Commit**

```bash
git add app/views/devise/sessions/new.html.erb app/views/devise/registrations/new.html.erb app/views/devise/shared/_links.html.erb app/views/devise/shared/_error_messages.html.erb test/integration/authentication_flow_test.rb
git commit -m "feat: structure auth pages for polished shell"
```

## Task 4: Extend the auth shell to password reset pages

**Files:**
- Modify: `app/views/devise/passwords/new.html.erb`
- Modify: `app/views/devise/passwords/edit.html.erb`
- Test: `test/integration/authentication_flow_test.rb`

**Interfaces:**
- Consumes: `.auth-header`, `.auth-title`, `.auth-copy`, `.auth-form`, `.auth-submit`, and `.auth-links` from Task 3.
- Produces: password reset request and change pages that share the same auth shell conventions.

- [ ] **Step 1: Write the failing test**

Add this test:

```ruby
test "password reset pages render the shared auth shell" do
  get new_user_password_url

  assert_response :success
  assert_select ".auth-shell", count: 1
  assert_select ".auth-title", text: "Forgot your password?"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: FAIL because the password reset views still use raw default Devise markup.

- [ ] **Step 3: Write minimal implementation**

```erb
<!-- app/views/devise/passwords/new.html.erb -->
<div class="auth-header">
  <h1 class="auth-title">Forgot your password?</h1>
  <p class="auth-copy">Enter your email and we’ll send password reset instructions.</p>
</div>

<%= form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :post, class: "auth-form" }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="auth-field">
    <%= f.label :email %>
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <%= f.submit "Send reset instructions", class: "auth-submit" %>
<% end %>

<%= render "devise/shared/links" %>
```

```erb
<!-- app/views/devise/passwords/edit.html.erb -->
<div class="auth-header">
  <h1 class="auth-title">Change your password</h1>
  <p class="auth-copy">Set a new password for your account.</p>
</div>

<%= form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :put, class: "auth-form" }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>
  <%= f.hidden_field :reset_password_token %>

  <div class="auth-field">
    <div class="auth-field__label-row">
      <%= f.label :password, "New password" %>
      <% if @minimum_password_length %>
        <span class="auth-hint"><%= @minimum_password_length %> characters minimum</span>
      <% end %>
    </div>
    <%= f.password_field :password, autofocus: true, autocomplete: "new-password" %>
  </div>

  <div class="auth-field">
    <%= f.label :password_confirmation, "Confirm new password" %>
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <%= f.submit "Change password", class: "auth-submit" %>
<% end %>

<%= render "devise/shared/links" %>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/devise/passwords/new.html.erb app/views/devise/passwords/edit.html.erb test/integration/authentication_flow_test.rb
git commit -m "feat: style password reset auth pages"
```

## Task 5: Add the auth design system to application.css

**Files:**
- Modify: `app/assets/stylesheets/application.css`
- Test: `test/integration/authentication_flow_test.rb`
- Test: `test/integration/listings_flow_test.rb`

**Interfaces:**
- Consumes: auth-shell classes from Tasks 2–4.
- Produces: CSS for `.auth-body`, `.auth-shell`, `.auth-card`, `.auth-header`, `.auth-title`, `.auth-copy`, `.auth-form`, `.auth-field`, `.auth-submit`, `.auth-links`, `.auth-errors`, `.auth-checkbox-row`, and auth-specific flash treatment while preserving listings styles.

- [ ] **Step 1: Write the failing test refinement**

Add these assertions:

```ruby
# test/integration/authentication_flow_test.rb
assert_includes response.body, "auth-card"
```

```ruby
# test/integration/listings_flow_test.rb
get listings_url
assert_response :success
assert_includes response.body, "feed-layout"
refute_includes response.body, "auth-shell"
```

Use a signed-in user for the listings integration check.

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/authentication_flow_test.rb test/integration/listings_flow_test.rb`

Expected: FAIL because the listings test does not yet assert separation, or because the CSS-facing class markers are incomplete before the final styling pass.

- [ ] **Step 3: Write minimal implementation**

Append CSS like this near the end of `app/assets/stylesheets/application.css`:

```css
.auth-body {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 1.5rem;
}

.auth-shell {
  width: 100%;
  max-width: 34rem;
}

.auth-card {
  background: rgba(255, 253, 249, 0.96);
  border: 1px solid var(--border);
  border-radius: 32px;
  box-shadow: var(--shadow);
  padding: 2rem;
  backdrop-filter: blur(10px);
}

.auth-brand {
  margin-bottom: 1rem;
  color: var(--muted);
  font-size: 0.78rem;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.auth-header {
  margin-bottom: 1.5rem;
}

.auth-title {
  margin: 0;
  font-size: clamp(2rem, 4vw, 2.5rem);
  line-height: 1.05;
}

.auth-copy {
  margin: 0.75rem 0 0;
  color: var(--muted);
  line-height: 1.6;
}

.auth-form {
  display: grid;
  gap: 1rem;
}

.auth-field {
  display: grid;
  gap: 0.45rem;
}

.auth-field label,
.auth-checkbox-row {
  font-weight: 600;
}

.auth-field input[type="email"],
.auth-field input[type="password"],
.auth-field input[type="text"] {
  width: 100%;
  min-height: 3.25rem;
  padding: 0.9rem 1rem;
  border: 1px solid var(--border);
  border-radius: 16px;
  background: var(--surface);
  color: var(--text);
  font: inherit;
}

.auth-field input:focus {
  outline: none;
  border-color: var(--border-strong);
  box-shadow: 0 0 0 4px rgba(220, 195, 160, 0.18);
}

.auth-field__label-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: baseline;
}

.auth-hint {
  color: var(--muted);
  font-size: 0.85rem;
}

.auth-checkbox-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  color: var(--muted);
}

.auth-submit {
  min-height: 3.3rem;
  border: 0;
  border-radius: 999px;
  background: linear-gradient(180deg, #f7efe3 0%, var(--accent) 100%);
  color: var(--text);
  font: inherit;
  font-weight: 800;
  cursor: pointer;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.6);
}

.auth-links {
  margin-top: 1.5rem;
  display: grid;
  gap: 0.65rem;
}

.auth-links p {
  margin: 0;
}

.auth-links a {
  color: var(--muted);
  text-decoration: none;
}

.auth-links a:hover,
.auth-links a:focus-visible {
  color: var(--text);
  text-decoration: underline;
}

.auth-errors,
.flash {
  margin-bottom: 1rem;
  padding: 0.9rem 1rem;
  border-radius: 16px;
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.78);
}

.auth-errors h2,
.auth-errors ul {
  margin: 0;
}

.auth-errors ul {
  margin-top: 0.6rem;
  padding-left: 1.2rem;
}

@media (max-width: 720px) {
  .auth-body {
    padding: 1rem;
  }

  .auth-card {
    padding: 1.5rem;
    border-radius: 24px;
  }

  .auth-field__label-row {
    flex-direction: column;
    align-items: start;
    gap: 0.35rem;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/authentication_flow_test.rb test/integration/listings_flow_test.rb`

Expected: PASS, confirming the auth-shell markers are present and the listings page remains separate.

- [ ] **Step 5: Commit**

```bash
git add app/assets/stylesheets/application.css test/integration/authentication_flow_test.rb test/integration/listings_flow_test.rb
git commit -m "feat: add auth page styling system"
```

## Task 6: Run full verification for presentation-only auth polish

**Files:**
- Test: `test/integration/authentication_flow_test.rb`
- Test: `test/integration/listings_flow_test.rb`
- Test: `test/**/*`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: verified auth styling changes with preserved auth behavior and unchanged app routing logic.

- [ ] **Step 1: Run the focused auth-related suite**

Run: `bin/rails test test/integration/authentication_flow_test.rb test/integration/listings_flow_test.rb`

Expected: PASS.

- [ ] **Step 2: Run the full test suite**

Run: `bin/rails test`

Expected: PASS with no regressions.

- [ ] **Step 3: Sanity-check the sign-in-first root route still exists**

Run: `bin/rails routes`

Expected: output still includes `root GET / listings#index`, `new_user_session`, and `new_user_registration`.

- [ ] **Step 4: Commit the final verified state**

```bash
git add .
git commit -m "feat: polish auth pages"
```

## Self-Review

- Spec coverage:
  - dedicated auth shell: Tasks 2–5
  - sign in and sign up styling: Task 3
  - shared links and error presentation: Task 3
  - optional password reset inclusion: Task 4
  - presentation-only, no auth behavior changes: enforced by Tasks 1 and 6 regression coverage
- Placeholder scan: every task contains concrete files, tests, commands, and code.
- Type consistency:
  - Auth shell classes used consistently: `.auth-shell`, `.auth-card`, `.auth-header`, `.auth-title`, `.auth-copy`, `.auth-form`, `.auth-field`, `.auth-submit`, `.auth-links`, `.auth-errors`.
  - Existing auth routes remain `new_user_session_url`, `new_user_registration_url`, `new_user_password_url`, and `listings_url`.
