# Staff Engineer Review: Environment & Configuration Management

## 1. Scope and Current Implementation

This review assesses the application configuration architecture, environment cascading, and the universal configuration facade implemented in [`lib/app_config.rb`](file:///home/devendra/work/App/lib/app_config.rb) and [`config/settings/`](file:///home/devendra/work/App/config/settings/).

### Current Implementation Details
- **Architecture**: Two-tier configuration hierarchy:
  1. Base settings: [`config/settings/settings.yml`](file:///home/devendra/work/App/config/settings/settings.yml) (loaded across all environments).
  2. Environment settings: `config/settings/settings-{environment}.yml` (deep-merged on top of base settings).
- **Evaluation**: Evaluated through ERB before YAML parsing, enabling dynamic environment variable interpolation.
- **Universal Facade (`AppConfig`)**:
  - `AppConfig.dig(*keys)`: Safely navigates nested configuration keys with symbol/string indifference, returning `nil` if missing.
  - `AppConfig.dig!(*keys)`: Raises a descriptive `KeyError` if a required key is missing or nil (fail-fast behavior).
  - `AppConfig.for(env)`: Allows explicit inspection of another environment's configuration (used in tests and cross-env tooling).
  - `AppConfig.reload!`: Clears memoized configurations, invoked automatically in `development.rb` on every request.
- **Local Environment Variables**:
  - Loaded via `gem "dotenv-rails"` in `:development` and `:test`.

---

## 2. Historical Context

- **Commit [`226fcb0`](file:///home/devendra/work/App) (2026-09-30)**: Added initial config setup.
- **Commit [`a55081f`](file:///home/devendra/work/App) (2026-10-12)**: Replaced disparate `ENV.fetch` calls across the codebase with `AppConfig` as the universal facade.
- **Commit [`b2c3686`](file:///home/devendra/work/App) (2026-10-13)**: Excluded `app_config.rb` from Zeitwerk's `autoload_lib` to prevent double-loading warnings.
- **Commit [`8a33368`](file:///home/devendra/work/App) (2026-10-20)**: Removed redundant global `DATABASE_NAME` environment overrides in CI to prevent cross-environment setting pollution.

---

## 3. Engineering Assessment

### A. Custom Facade vs Built-in Rails `config_for`
Rails provides `Rails.application.config_for(:settings)`.
- **Why `AppConfig` Earns Its Place**:
  1. It provides `dig!` with fail-fast exception throwing for missing keys.
  2. It decouples low-level ERB environment variable overrides from consumer code (e.g. `config/database.yml`, `config/initializers/cors.rb`, and mailers).
  3. It permits clean cross-environment querying (`AppConfig.for(:test)`).
- **Test Coverage**: Fully covered by unit tests in [`spec/lib/app_config_spec.rb`](file:///home/devendra/work/App/spec/lib/app_config_spec.rb).

### B. Environment Variable Leaks & Precedence
In `settings-*.yml`, the project uses the cascade:
```erb
<%= ENV["DATABASE_HOST"].presence || Rails.application&.credentials&.dig(:database, :host) %>
```
This is the canonical 12-factor pattern: secrets default to encrypted credentials in Git, but can be seamlessly overridden at runtime via process environment variables without modifying source code.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **CFG-01** | **Pass** | Low | Deep symbolized indifferent access prevents string/symbol mismatch bugs | [`lib/app_config.rb`](file:///home/devendra/work/App/lib/app_config.rb) recursively symbolizes all keys when loading YAML. |
| **CFG-02** | **Pass** | Low | Development auto-reload ensures instant feedback | [`config/environments/development.rb:83`](file:///home/devendra/work/App/config/environments/development.rb#L83) calls `AppConfig.reload!` on request reloads. |

---

## 5. Recommended Approach

The configuration architecture is clean, expressive, and thoroughly tested. **Keep unchanged.**

---

## 6. Standard Approach for Future Projects

- Structure configuration around a unified facade rather than spreading raw `ENV["..."]` calls across initializers.
- Provide both safe `dig` and fail-fast `dig!` accessors.
- Keep non-sensitive settings in YAML and point ERB tags to encrypted credentials or `ENV`.

---

## 7. Verification Checklist

- [x] Base settings merge cleanly with environment settings.
- [x] Missing required keys raise `KeyError` via `dig!`.
- [x] `AppConfig.for(:development)` and `AppConfig.for(:test)` load without collisions.

---

## 8. References
- 12-Factor App Config Principle: https://12factor.net/config
- Rails Configuration Guide: https://guides.rubyonrails.org/configuring.html
