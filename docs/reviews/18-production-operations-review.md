# Staff Engineer Review: Production Operations & Observability

## 1. Scope and Current Implementation

This review assesses production telemetry, structured logging, health check probes, cloud storage enforcement, email delivery, and operational readiness across [`config/environments/production.rb`](file:///home/devendra/work/App/config/environments/production.rb), [`app/controllers/health_controller.rb`](file:///home/devendra/work/App/app/controllers/health_controller.rb), and [`config/storage.yml`](file:///home/devendra/work/App/config/storage.yml).

### Current Implementation Details
- **Dual Health Check Architecture**:
  1. **Shallow Check (`GET /up`)**:
     - Provided natively by Rails 8 (`rails/health#show`).
     - Verifies that the Puma process is alive and responsive.
  2. **Deep Check (`GET /up/deep`)**:
     - Implemented in [`app/controllers/health_controller.rb`](file:///home/devendra/work/App/app/controllers/health_controller.rb).
     - Probes PostgreSQL database: `ActiveRecord::Base.connection.execute("SELECT 1")`.
     - Probes Redis server: `Sidekiq.redis { |c| c.ping } == "PONG"`.
     - Returns `200 OK` when both services are connected; returns `503 Service Unavailable` with degraded status if either service drops.
  3. **SSL Redirection Exemption**:
     - [`config/environments/production.rb:34`](file:///home/devendra/work/App/config/environments/production.rb#L34) exempts `/up*` from forced HTTPS redirects, preventing cloud load balancers from receiving 301 redirects on HTTP health probes.
  4. **Log Silencing**:
     - `config.silence_healthcheck_path = "/up"` prevents high-frequency load balancer probes from polluting production application logs.
- **Tagged Logging**:
  - `config.log_tags = [ :request_id ]`
  - `config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)`
  - Streams logs directly to container STDOUT with unique request IDs for distributed trace correlation.
- **Remote Cloud Storage Enforcement**:
  - [`config/environments/production.rb:25`](file:///home/devendra/work/App/config/environments/production.rb#L25) sets `config.active_storage.service = :amazon`.
  - Prohibits accidental fallback to ephemeral container disk storage.
- **Email Operations**:
  - SMTP delivery configured dynamically via `AppConfig.dig(:smtp, ...)`.
  - Mailer host decoupling: `default_url_options[:host]` resolves from `AppConfig.dig(:app_host)`.
  - Development previewing: `LetterOpenerWeb` mounted at `/letter_opener`.

---

## 2. Historical Context

- **Commit [`9428295`](file:///home/devendra/work/App) (2026-10-10)**: Configured AWS S3 Active Storage.
- **Commit [`d4cbc43`](file:///home/devendra/work/App) (2026-10-13)**: Enforced `:amazon` service in production without disk fallback.
- **Commit [`9f9ad42`](file:///home/devendra/work/App) (2026-10-13)**: Decoupled mailer host from SMTP domain.
- **Commit [`facc785`](file:///home/devendra/work/App) (2026-10-11)**: Added `letter_opener_web` for development.
- **Commit [`6df2174`](file:///home/devendra/work/App) (2026-10-21)**: Added deep health check at `/up/deep` and updated SSL exemption.

---

## 3. Engineering Assessment

### A. Dual Probe Strategy
Cloud orchestrators (AWS ALB, Kubernetes, ECS) require two distinct probe types:
- **Liveness Probe**: Should use `/up`. If a process hangs or deadlocks, restart the container. (Should not fail just because an external DB is experiencing a temporary spike).
- **Readiness Probe**: Should use `/up/deep`. If the database or Redis is disconnected, remove the container from routing rotation immediately so incoming user requests aren't routed to a broken instance.
- Providing both endpoints aligns the application with modern SRE best practices.

### B. Ephemeral Disk Protection
In Docker and Kubernetes environments, container local storage is ephemeral. Commits `d4cbc43` strictly enforcing `:amazon` S3 storage ensures user uploads are never written to container filesystems that disappear upon container restarts.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **OPS-01** | **Pass** | High | Deep health check isolates DB and Redis outages | Tested in `spec/requests/health_spec.rb`. |
| **OPS-02** | **Pass** | High | Production uploads are enforced on remote S3 storage | `config.active_storage.service = :amazon` in `production.rb:25`. |
| **OPS-03** | **Pass** | Medium | Request IDs are tagged on all log outputs | `config.log_tags = [ :request_id ]` in `production.rb:37`. |
| **OPS-04** | **Optional** | Low | Exception reporting service (e.g., Sentry) not yet installed | Can be hooked in via `Rails.error.subscribe` when SaaS provider is chosen. |

---

## 5. Recommended Approach

The operational foundation is robust, observable, and container-ready. When an error tracking provider (Sentry/Bugsnag) is selected, plug it in via `Rails.error.subscribe`. **Keep unchanged.**

---

## 6. Standard Approach for Future Projects

- Provide both shallow (`/up`) and deep (`/up/deep`) health checks.
- Exempt health checks from SSL redirects and log outputs.
- Tag logs with `:request_id`.
- Never use local disk storage in production container environments.

---

## 7. Verification Checklist

- [x] `/up` returns 200 OK.
- [x] `/up/deep` returns 200 OK with JSON when DB and Redis are connected.
- [x] `/up/deep` returns 503 Service Unavailable when DB is down.
- [x] Request ID appears in STDOUT logs.

---

## 8. References
- Rails 8 Health Check Guide: https://guides.rubyonrails.org/configuring.html#rails-health-check
- Kubernetes Liveness and Readiness Probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
