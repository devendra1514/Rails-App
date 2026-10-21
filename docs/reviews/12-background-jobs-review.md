# Staff Engineer Review: Background Processing & Scheduling

## 1. Scope and Current Implementation

This review assesses background job architecture, execution hierarchies, queuing priorities, periodic job scheduling, and worker monitoring across [`config/sidekiq.yml`](file:///home/devendra/work/App/config/sidekiq.yml), [`config/initializers/sidekiq.rb`](file:///home/devendra/work/App/config/initializers/sidekiq.rb), [`config/schedule.yml`](file:///home/devendra/work/App/config/schedule.yml), and [`app/sidekiq/application_job.rb`](file:///home/devendra/work/App/app/sidekiq/application_job.rb).

### Current Implementation Details
- **Job Engine**: Sidekiq 8.1 (`gem "sidekiq"`).
- **Periodic Scheduler**: `sidekiq-cron` (`gem "sidekiq-cron"`).
- **Worker Hierarchy**:
  - Pure Sidekiq Job base class: [`app/sidekiq/application_job.rb`](file:///home/devendra/work/App/app/sidekiq/application_job.rb) includes `Sidekiq::Job`.
  - ActiveJob Adapter: [`config/application.rb:48`](file:///home/devendra/work/App/config/application.rb#L48) sets `config.active_job.queue_adapter = :sidekiq`.
  - ActionMailer deliveries automatically route through Sidekiq's `mailers` queue.
- **Queue Priority Configuration ([`config/sidekiq.yml`](file:///home/devendra/work/App/config/sidekiq.yml))**:
  - `critical` (weight 3)
  - `default` (weight 2)
  - `mailers` (weight 2)
  - `low` (weight 1)
  - Worker concurrency dynamically mirrors web thread concurrency:
    ```yaml
    concurrency: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
    ```
- **Middleware**:
  - Prosopite N+1 query detection added to Sidekiq server middleware in development/test.
- **Web UI**:
  - Mounted at `/admin/sidekiq` in [`config/routes.rb:12-14`](file:///home/devendra/work/App/config/routes.rb#L12-L14) behind Devise `authenticate :admin`.

---

## 2. Historical Context

- **Commit [`5dc08ae`](file:///home/devendra/work/App) (2026-09-29)**: Replaced Solid Queue with Sidekiq.
- **Commit [`cd585fe`](file:///home/devendra/work/App) (2026-09-30)**: Added Sidekiq server/client initializers.
- **Commit [`a2159f1`](file:///home/devendra/work/App) (2026-09-30)**: Added `sidekiq-cron` and `config/schedule.yml`.
- **Commit [`a33e770`](file:///home/devendra/work/App) (2026-10-10)**: Removed default Rails ActiveJob `ApplicationJob` and established pure `Sidekiq::Job` in `app/sidekiq/application_job.rb`.
- **Commit [`aabf285`](file:///home/devendra/work/App) (2026-10-10)**: Thread and Sidekiq concurrency alignment.
- **Commit [`ebabeea`](file:///home/devendra/work/App) (2026-10-10)**: Secured Sidekiq Web UI behind Devise SSO.
- **Commit [`a50fe15`](file:///home/devendra/work/App) (2026-10-13)**: Documented native `Sidekiq::Cron::ScheduleLoader` behavior.

---

## 3. Engineering Assessment

### A. Pure `Sidekiq::Job` vs `ActiveJob`
The decision to standardize on `Sidekiq::Job` rather than wrapping all jobs in `ActiveJob::Base` is a defensible engineering choice:
1. Pure Sidekiq jobs serialize payloads directly to JSON without ActiveJob's GlobalID abstraction overhead.
2. Sidekiq-native features (batching, unique jobs, custom retry delays, direct client middleware) work without impedance mismatch.
3. System components requiring ActiveJob (specifically ActionMailer's `deliver_later`) coexist seamlessly via `config.active_job.queue_adapter = :sidekiq`.

### B. Auto-Loading Cron Schedules
Modern versions of `sidekiq-cron` feature an internal `ScheduleLoader` hook that automatically loads `config/schedule.yml` when the Sidekiq server boots, eliminating the need to manually invoke `Sidekiq::Cron::Job.load_from_hash` in an initializer.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **JOB-01** | **Pass** | High | Sidekiq Web UI is protected against unauthorized public access | [`config/routes.rb:12-14`](file:///home/devendra/work/App/config/routes.rb#L12-L14) requires active admin session. |
| **JOB-02** | **Pass** | Medium | Queues are explicitly prioritized with weights | [`config/sidekiq.yml:5-9`](file:///home/devendra/work/App/config/sidekiq.yml#L5-L9) prioritizes critical and mailer jobs over low-priority tasks. |
| **JOB-03** | **Pass** | Low | Concurrency matches database connection limits | Configured via `RAILS_MAX_THREADS` fallback. |

---

## 5. Recommended Approach

The background processing setup is enterprise-grade, performant, and secure. **Keep unchanged.**

---

## 6. Standard Approach for Future Projects

- Route mailer jobs to an explicit `mailers` queue.
- Use weighted queues (`critical`, `default`, `mailers`, `low`).
- Mount Sidekiq Web behind administrative authentication.
- Always clear queues in test teardown hooks.

---

## 7. Verification Checklist

- [x] Sidekiq connects to Redis server.
- [x] Sidekiq Web UI redirects unauthenticated visitors to `/admin/login`.
- [x] Test suite executes jobs in fake mode without network calls.

---

## 8. References
- Sidekiq Best Practices: https://github.com/sidekiq/sidekiq/wiki/Best-Practices
- Sidekiq-Cron Documentation: https://github.com/sidekiq-cron/sidekiq-cron
