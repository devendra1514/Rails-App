# Background Jobs and Scheduling Setup

## 1. Overview

This document details the **asynchronous job processing and recurring schedule framework** established in this application using **Sidekiq 8** and **Sidekiq-Cron** backed by **Redis 7**.

- **Type**: Asynchronous Processing / Distributed Job Queue.
- **Problem Solved**:
  - Offloads time-consuming tasks (email delivery, external API calls, data imports, cache warmers) from the synchronous HTTP request/response cycle.
  - Provides weighted priority queues to prevent low-priority background work from starving critical business operations.
  - Manages distributed recurring cron schedules that automatically execute across container restarts.
  - Integrates automated N+1 query detection into background worker pipelines.

---

## 2. Historical Timeline

| Commit | Date | Author / Context | Files Changed | Technical Change Introduced |
| :--- | :--- | :--- | :--- | :--- |
| [`5dc08ae`](file:///home/devendra/work/App) | 2026-09-29 | Stack Replacement | `Gemfile`, `config/environments/` | Removed default Rails 8 `solid_queue`. |
| [`cd585fe`](file:///home/devendra/work/App) | 2026-10-02 | Sidekiq Introduction | `Gemfile`, `config/sidekiq.yml`, `config/initializers/sidekiq.rb` | Added `sidekiq` gem. Configured 4 weighted queues: `critical` (3), `default` (2), `mailers` (2), `low` (1). Wired Redis URL via `AppConfig.dig(:redis, :url)`. |
| [`a2159f1`](file:///home/devendra/work/App) | 2026-10-02 | Scheduled Jobs | `Gemfile`, `config/schedule.yml`, `config/initializers/sidekiq.rb` | Added `sidekiq-cron` gem. Integrated automatic schedule loading from `config/schedule.yml` on server boot. |
| [`a33e770`](file:///home/devendra/work/App) | 2026-10-05 | Worker Pattern | `app/jobs/` | Removed default `ApplicationJob < ActiveJob::Base` template in favor of native Sidekiq worker execution. |
| [`aabf285`](file:///home/devendra/work/App) | 2026-10-05 | Concurrency Fallback | `config/sidekiq.yml` | Tied Sidekiq concurrency to `SIDEKIQ_CONCURRENCY` or `RAILS_MAX_THREADS` (default 5). |
| [`6c4d531`](file:///home/devendra/work/App) | 2026-10-06 | Schedule Resilience | `config/schedule.yml` | Added valid empty YAML root map (`{}`) to prevent `Psych::SyntaxError` when no cron jobs are registered. |
| [`1953432`](file:///home/devendra/work/App) | 2026-10-12 | N+1 Detection | `config/initializers/sidekiq.rb` | Added `Prosopite::Middleware::Sidekiq` server middleware to detect N+1 database queries inside background jobs. |
| [`ebabeea`](file:///home/devendra/work/App) | 2026-10-13 | Security Remediation (SEC-01) | `config/routes.rb` | Mounted `Sidekiq::Web` at `/admin/sidekiq` behind Devise `authenticate :admin` SSO constraint, closing open dashboard vulnerability. |
| [`fc5498e`](file:///home/devendra/work/App) | 2026-10-19 | Pre-Rails ERB Fix | `config/sidekiq.yml` | Replaced ActiveSupport `.presence` call with pure Ruby `.to_s.empty? ? ... : ...` fallback so Sidekiq CLI evaluates concurrency before Rails boots. |
| [`0e666e4`](file:///home/devendra/work/App) | 2026-10-19 | Container Orchestration | `docker-compose.yml` | Added dedicated `sidekiq` worker container sharing the `Dockerfile.dev` image with healthcheck synchronization. |

---

## 3. Why This Setup Was Introduced

- **Verified Reason (Solid Queue to Sidekiq Replacement)**: Commit [`5dc08ae`](file:///home/devendra/work/App). The project standardized on Redis and Sidekiq for battle-tested multithreaded concurrency, enterprise monitoring tooling, and mature cron extensions.
- **Verified Reason (Sidekiq Web UI SSO - SEC-01)**: Documented in technical audit (`fund/audit/01-findings.md` Finding **HIGH-01**) and resolved in [`ebabeea`](file:///home/devendra/work/App). `Sidekiq::Web` was originally mounted without authentication, exposing queue manipulation, job payload inspection, and queue flushing to the open internet. Mounting behind `authenticate :admin` secures the UI completely.
- **Verified Reason (Pure Ruby Concurrency Fix)**: Discovered and solved during container boot testing in commit [`fc5498e`](file:///home/devendra/work/App). When Sidekiq boots from CLI (`bundle exec sidekiq`), it parses `config/sidekiq.yml` with ERB *before* requiring Rails. Calling `nil.presence` raised `NoMethodError: undefined method 'presence' for nil`. Pure Ruby fallback ensures clean execution in both Rails and standalone contexts.

---

## 4. Files and Configuration Explained

### 1. Queue and Concurrency Configuration: [`config/sidekiq.yml`](file:///home/devendra/work/App/config/sidekiq.yml)
```yaml
:concurrency: <%= ENV["SIDEKIQ_CONCURRENCY"].to_s.empty? ? ENV.fetch("RAILS_MAX_THREADS", 5) : ENV["SIDEKIQ_CONCURRENCY"] %>
:queues:
  - ["critical", 3]
  - ["default", 2]
  - ["mailers", 2]
  - ["low", 1]

development:
  :concurrency: <%= ENV["SIDEKIQ_CONCURRENCY"].to_s.empty? ? ENV.fetch("RAILS_MAX_THREADS", 5) : ENV["SIDEKIQ_CONCURRENCY"] %>

test:
  :concurrency: 1

production:
  :concurrency: <%= ENV["SIDEKIQ_CONCURRENCY"].to_s.empty? ? ENV.fetch("RAILS_MAX_THREADS", 5) : ENV["SIDEKIQ_CONCURRENCY"] %>
```
- **Weighted Queues**: Numbers denote relative polling weight. For every 8 jobs processed: `critical` gets 3, `default` gets 2, `mailers` gets 2, and `low` gets 1.
- **Concurrency**: Defaults to matching database connection pool (`RAILS_MAX_THREADS = 5`).

### 2. Sidekiq Initializer: [`config/initializers/sidekiq.rb`](file:///home/devendra/work/App/config/initializers/sidekiq.rb)
```ruby
# frozen_string_literal: true

redis_url = AppConfig.dig(:redis, :url)

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url } if redis_url.present?

  if defined?(Prosopite) && (Rails.env.development? || Rails.env.test?)
    config.server_middleware do |chain|
      require "prosopite/middleware/sidekiq"
      chain.add(Prosopite::Middleware::Sidekiq)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url } if redis_url.present?
end
```
- **Dynamic Redis Connection**: Obtains connection string via `AppConfig.dig(:redis, :url)`.
- **Prosopite Middleware**: Automatically catches N+1 queries executed inside background jobs in development and test environments.

### 3. Cron Schedules: [`config/schedule.yml`](file:///home/devendra/work/App/config/schedule.yml)
```yaml
# Sidekiq-Cron schedule configuration
# Add recurring jobs here using standard cron syntax:
#
# daily_report:
#   cron: "0 0 * * *"
#   class: "DailyReportWorker"
#   queue: "default"
{}
```

### 4. Authenticated Web Routing: [`config/routes.rb`](file:///home/devendra/work/App/config/routes.rb#L1-L15)
```ruby
require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Secure Sidekiq Web UI behind Admin Devise session (resolves SEC-01)
  authenticate :admin do
    mount Sidekiq::Web => "/admin/sidekiq"
  end
end
```

---

## 5. Dependencies and Prerequisites

- **Gems**:
  - `gem "sidekiq"` (locked at `8.1.7`)
  - `gem "sidekiq-cron"` (locked at `2.4.0`)
  - `gem "redis"` (locked at `5.4.0`)
- **Services**: Redis 7+ instance reachable via `REDIS_URL`.
- **Authentication**: Requires `Admin` model authenticated via Devise.

---

## 6. How the Setup Works

```mermaid
flowchart TD
    subgraph EnqueueFlow["Job Enqueuing Flow"]
        Controller["Rails Web / Service"] -->|MyWorker.perform_async(id)| Client["Sidekiq::Client"]
        Client -->|AppConfig.dig(:redis, :url)| RedisQueue[("Redis (Queue Sets)")]
    end

    subgraph ScheduleFlow["Recurring Schedule Flow"]
        CronFile["config/schedule.yml"] --> SidekiqCron["Sidekiq::Cron::Job.load_from_hash!"]
        SidekiqCron --> RedisSchedule[("Redis (Cron Poller)")]
        RedisSchedule -->|Cron trigger| RedisQueue
    end

    subgraph WorkerFlow["Job Execution Flow"]
        WorkerProcess["Sidekiq Server Process (PID)"] -->|Poll weighted queues| RedisQueue
        WorkerProcess --> ProsopiteMiddleware["Prosopite Middleware (N+1 check)"]
        ProsopiteMiddleware --> WorkerClass["Execute Worker#perform"]
    end
```

---

## 7. How to Reproduce the Setup

### Step 1: Add Dependencies
Add to `Gemfile`:
```ruby
gem "sidekiq"
gem "redis"
gem "sidekiq-cron"
```
Run `bundle install`.

### Step 2: Configure Queues
Create `config/sidekiq.yml` with weighted queues and pure Ruby concurrency fallback (see section 4).

### Step 3: Create Initializer
Create `config/initializers/sidekiq.rb` connecting to `AppConfig.dig(:redis, :url)` and registering Prosopite middleware.

### Step 4: Secure Web UI
In `config/routes.rb`:
```ruby
require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  authenticate :admin do
    mount Sidekiq::Web => "/admin/sidekiq"
  end
end
```

---

## 8. Verification and Operational Notes

| Verification Check | Target | Execution Command | Expected Output | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Sidekiq Redis Ping** | Host | `bin/rails runner "puts Sidekiq.redis(&:ping)"` | `PONG` | Executed & Verified |
| **Worker Container Boot** | Docker | `docker compose up -d sidekiq` | `Container app-sidekiq-1 Started` | Executed & Verified |
| **Queue Polling Logs** | Docker | `docker compose logs sidekiq` | `Booted Rails application ... Sidekiq connecting to Redis` | Executed & Verified |
| **Authenticated Web UI** | Host | `curl -I http://localhost:3000/admin/sidekiq` | `302 Found` (redirect to `/admin/login`) | Executed & Verified |
| **Web UI RSpec Specs** | Host | `bundle exec rspec spec/requests/admin/authentication_spec.rb` | 7 examples, 0 failures | Executed & Verified |

---

## 9. Current Status and Recommendations

- **Current Status**: Production-hardened with zero-trust admin authentication, weighted queue management, and N+1 query safety.
- **Recommendations**:
  - Always assign custom workers to appropriate queues (`sidekiq_options queue: :critical` or `:low`).
  - Monitor memory usage of Sidekiq processes in production and size concurrency to match available database connections.

---

## 10. References

- **Git Commits**:
  - Initial setup: [`cd585fe`](file:///home/devendra/work/App)
  - Sidekiq-cron: [`a2159f1`](file:///home/devendra/work/App), [`6c4d531`](file:///home/devendra/work/App)
  - Concurrency fallback: [`aabf285`](file:///home/devendra/work/App), [`fc5498e`](file:///home/devendra/work/App)
  - Security SSO: [`ebabeea`](file:///home/devendra/work/App)
  - Docker service: [`0e666e4`](file:///home/devendra/work/App)
- **Files**:
  - [`config/sidekiq.yml`](file:///home/devendra/work/App/config/sidekiq.yml)
  - [`config/initializers/sidekiq.rb`](file:///home/devendra/work/App/config/initializers/sidekiq.rb)
  - [`config/schedule.yml`](file:///home/devendra/work/App/config/schedule.yml)
  - [`config/routes.rb`](file:///home/devendra/work/App/config/routes.rb)
- **External Documentation**:
  - [Sidekiq Official Documentation](https://github.com/sidekiq/sidekiq/wiki)
  - [Sidekiq Monitoring Security](https://github.com/sidekiq/sidekiq/wiki/Monitoring#security)
  - [Sidekiq-Cron Documentation](https://github.com/sidekiq-cron/sidekiq-cron)
