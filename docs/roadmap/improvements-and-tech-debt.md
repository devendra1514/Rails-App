# Application Foundation Roadmap: Future Improvements & Technical Debt

## 1. Overview & Prioritization Matrix

This document tracks all identified technical debt, framework version upgrades, performance optimizations, and future enhancements identified during the Staff Engineer architecture audits.

Every item is classified by urgency, business impact, and implementation complexity.

```mermaid
quadrantChart
    title Technical Debt vs. Value Matrix
    x-axis Low Effort --> High Effort
    y-axis Low Value / Nice-to-Have --> High Value / Critical
    quadrant-1 Strategic Evolution
    quadrant-2 Quick Wins (High Priority)
    quadrant-3 Low Priority / Defer
    quadrant-4 Re-architect When Needed
    "Pagy Security Upgrade (CVE-2026-54659)": [0.15, 0.85]
    "Thread / Pool Fallback Alignment": [0.08, 0.70]
    "Production Seed Logging": [0.05, 0.55]
    "ActiveAdmin GA Release Pin": [0.25, 0.65]
    "Redis Cache Index Segregation": [0.20, 0.50]
    "Standardized ApiController Responders": [0.35, 0.60]
    "Unified Error Subscriber (Sentry)": [0.30, 0.75]
    "Non-Docker Procfile.dev": [0.15, 0.35]
```

---

## 2. Priority 1: High Priority & Security Remediation

### 1.1 Pagy Gem Security Upgrade (CVE-2026-54659)
- **Component**: [`Gemfile`](file:///home/devendra/work/App/Gemfile) & [`.github/workflows/ci.yml`](file:///home/devendra/work/App/.github/workflows/ci.yml)
- **Priority**: **High**
- **Effort**: 15 minutes
- **Context**: 
  A security advisory was published for `pagy 43.4.4` (CVE-2026-54659) regarding improper input validation in the I18n locale option. CI currently suppresses this warning using the `--ignore CVE-2026-54659` flag.
- **Action Required**:
  1. Run `bundle update pagy` to upgrade to version `43.5.6` or later.
  2. Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec` to ensure all pagination specs pass.
  3. Remove `--ignore CVE-2026-54659` from line 29 of [`.github/workflows/ci.yml`](file:///home/devendra/work/App/.github/workflows/ci.yml#L29).
  4. Verify `bundle exec bundler-audit` exits with status `0`.

---

## 3. Priority 2: Operational Tuning & Reliability

### 2.1 Synchronize Thread & Connection Pool Fallback Integers
- **Component**: [`config/database.yml`](file:///home/devendra/work/App/config/database.yml#L4) & [`config/puma.rb`](file:///home/devendra/work/App/config/puma.rb#L28)
- **Priority**: **Medium**
- **Effort**: 5 minutes
- **Context**:
  In [`config/database.yml:4`](file:///home/devendra/work/App/config/database.yml#L4), the connection pool defaults to `5` if `RAILS_MAX_THREADS` is missing:
  ```yaml
  max_connections: <%= ENV["DB_POOL"].presence || ENV.fetch("RAILS_MAX_THREADS", 5) %>
  ```
  In [`config/puma.rb:28`](file:///home/devendra/work/App/config/puma.rb#L28), Puma thread count defaults to `3`:
  ```ruby
  threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
  ```
  While safe in practice (5 pool connections >= 3 Puma threads prevents connection starvation), setting both fallback integers symmetrically to `5` eliminates configuration divergence when running without environment variables.
- **Action Required**:
  Update [`config/puma.rb:28`](file:///home/devendra/work/App/config/puma.rb#L28) to fallback to `5`.

### 2.2 ActiveAdmin Official GA Release Graduation
- **Component**: [`Gemfile`](file:///home/devendra/work/App/Gemfile#L65)
- **Priority**: **Medium**
- **Effort**: 30 minutes
- **Context**:
  ActiveAdmin is currently pinned to `gem "activeadmin", ">= 4.0.0.beta21"` to ensure compatibility with Rails 8's Propshaft asset pipeline.
- **Action Required**:
  Once ActiveAdmin v4 reaches final General Availability (GA), update the `Gemfile` constraint from the beta release to `~> 4.0.0` and run the request test suite.

### 2.3 Informative Production Seeding Warnings
- **Component**: [`db/seeds.rb`](file:///home/devendra/work/App/db/seeds.rb#L16-L22)
- **Priority**: **Medium**
- **Effort**: 5 minutes
- **Context**:
  When `bin/rails db:seed` executes in production, if `INITIAL_ADMIN_EMAIL` and `INITIAL_ADMIN_PASSWORD` are missing, the seed exits silently without creating an admin user.
- **Action Required**:
  Add an `else` branch logging a warning:
  ```ruby
  else
    Rails.logger.warn("[Seeds] INITIAL_ADMIN_EMAIL or INITIAL_ADMIN_PASSWORD missing. Skipping admin creation.")
  end
  ```

---

## 4. Priority 3: Architecture & Performance Evolution

### 4.1 Redis Keyspace & Database Index Segregation
- **Component**: [`config/settings/settings-production.yml`](file:///home/devendra/work/App/config/settings/settings-production.yml)
- **Priority**: **Low**
- **Effort**: 20 minutes
- **Context**:
  Currently, Sidekiq queues, Action Cable WebSockets, and `Rails.cache` share the same Redis URL (index `/0`). While Sidekiq and Action Cable use distinct namespace prefixes, an accidental `Rails.cache.clear` in an incident could impact other keys.
- **Action Required**:
  Add a dedicated `REDIS_CACHE_URL` pointing to index `/1` in production settings and update [`config/environments/production.rb:50`](file:///home/devendra/work/App/config/environments/production.rb#L50).

### 4.2 Standardized `ApiController` Responders & Error Rescue
- **Component**: [`app/controllers/api_controller.rb`](file:///home/devendra/work/App/app/controllers/api_controller.rb)
- **Priority**: **Low (Implement when building API endpoints)**
- **Effort**: 45 minutes
- **Context**:
  `ApiController` currently includes `Pagy::Method`. When customer-facing JSON APIs are introduced, standardized JSON responders (`render_success`, `render_error`) and standard `rescue_from` handlers for `ActiveRecord::RecordNotFound` (404) and `ActiveRecord::RecordInvalid` (422) should be established.

### 4.3 Unified Error Reporting Subscriber (Sentry / Bugsnag)
- **Component**: `config/initializers/error_subscriber.rb`
- **Priority**: **Low (Implement when APM provider is selected)**
- **Effort**: 30 minutes
- **Context**:
  Rails 8 features `Rails.error.subscribe`. Registering a subscriber centralizes unhandled exception reporting across Puma controllers and Sidekiq background jobs into a single configuration point.

### 4.4 Non-Docker Multi-Process Runner (`Procfile.dev`)
- **Component**: `Procfile.dev` & [`bin/dev`](file:///home/devendra/work/App/bin/dev)
- **Priority**: **Low**
- **Effort**: 15 minutes
- **Context**:
  The Docker Compose stack (`docker compose up`) already runs both Puma and Sidekiq simultaneously. For team members who develop directly on the host machine without Docker, a `Procfile.dev` with `foreman` or `overmind` allows booting both processes with `bin/dev`.

---

## 5. Summary Tracking Table

| ID | Title | Priority | Category | Target Release | Status |
| :--- | :--- | :---: | :--- | :---: | :---: |
| **TODO-01** | Update Pagy to `>= 43.5.6` (CVE-2026-54659) | **High** | Security | Next Sprint | Ready |
| **TODO-02** | Align Puma/DB thread fallback integers to `5` | **Medium** | Config Symmetry | Next Sprint | Ready |
| **TODO-03** | Update ActiveAdmin from Beta to GA release | **Medium** | Dependencies | When v4 GA drops | Backlogged |
| **TODO-04** | Add logging for missing admin seed variables | **Medium** | Operations | Next Sprint | Ready |
| **TODO-05** | Split Redis Cache index to `/1` | **Low** | Performance | Pre-Launch | Backlogged |
| **TODO-06** | Standardize ApiController JSON responders | **Low** | Architecture | Feature Phase | Backlogged |
| **TODO-07** | Implement `Rails.error.subscribe` hook | **Low** | Observability | Pre-Launch | Backlogged |
| **TODO-08** | Add `Procfile.dev` for host-native developers | **Low** | Developer UX | Optional | Backlogged |
