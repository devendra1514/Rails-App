# Enterprise Rails 8 Foundation Documentation

Welcome to the central documentation hub for this production Ruby on Rails 8 application starter foundation.

This documentation captures the complete technical knowledge, architectural decisions, step-by-step reproduction instructions, Staff-level engineering audits, and future roadmap for the application.

---

## 1. Documentation Structure

```text
docs/
├── README.md                          # Master documentation index (this file)
├── architecture/                      # Technical architecture & step-by-step reproduction guides
│   ├── 01-ruby-runtime-and-version-setup.md
│   ├── 02-rails-application-setup.md
│   ├── 03-database-and-migrations-setup.md
│   ├── 04-environment-and-configuration-management-setup.md
│   ├── 05-secrets-and-credentials-setup.md
│   ├── 06-background-jobs-and-scheduling-setup.md
│   ├── 07-redis-and-caching-setup.md
│   ├── 08-file-storage-setup.md
│   ├── 09-email-delivery-and-preview-setup.md
│   ├── 10-security-and-abuse-prevention-setup.md
│   ├── 11-authentication-and-admin-setup.md
│   ├── 12-testing-infrastructure-setup.md
│   ├── 13-code-quality-and-performance-setup.md
│   ├── 14-docker-production-environment-setup.md
│   ├── 15-docker-development-environment-setup.md
│   └── devise_jwt_auth_guide.md
├── reviews/                           # Evidence-based Staff Engineer component audits
│   ├── 01-ruby-version-review.md
│   ├── 02-rails-application-review.md
│   ├── 03-dependency-management-review.md
│   ├── 04-database-review.md
│   ├── 05-environment-configuration-review.md
│   ├── 06-secrets-management-review.md
│   ├── 07-application-initialization-review.md
│   ├── 08-development-server-review.md
│   ├── 09-testing-infrastructure-review.md
│   ├── 10-code-quality-review.md
│   ├── 11-authentication-review.md
│   ├── 12-background-jobs-review.md
│   ├── 13-redis-review.md
│   ├── 14-caching-review.md
│   ├── 15-security-review.md
│   ├── 16-docker-review.md
│   ├── 17-ci-cd-review.md
│   └── 18-production-operations-review.md
└── roadmap/
    └── improvements-and-tech-debt.md  # Prioritized backlog of technical debt & future upgrades
```

---

## 2. Architecture & Reproduction Guides

Comprehensive guides detailing why each component exists, how files interact, dependencies, and execution flows:

| Document | Topic | Description |
| :--- | :--- | :--- |
| **[01. Ruby Runtime](architecture/01-ruby-runtime-and-version-setup.md)** | Ruby 3.3.6 | Single source of truth across `.ruby-version`, Bundler, Docker, YJIT, and jemalloc. |
| **[02. Rails Application](architecture/02-rails-application-setup.md)** | Rails 8.1.4 | Baseline initialization, Zeitwerk autoloading, UTC timezones, and generator defaults. |
| **[03. Database & Migrations](architecture/03-database-and-migrations-setup.md)** | PostgreSQL | Dynamic connection pooling, `strong_migrations` protection, and decoupled migration strategy. |
| **[04. Configuration](architecture/04-environment-and-configuration-management-setup.md)** | `AppConfig` Facade | Centralized configuration facade, YAML hierarchy, dynamic ERB parsing, and request reloading. |
| **[05. Secrets Management](architecture/05-secrets-and-credentials-setup.md)** | Encrypted Credentials | Multi-environment AES-256 credentials, master key handling, and secret-free Docker builds. |
| **[06. Background Jobs](architecture/06-background-jobs-and-scheduling-setup.md)** | Sidekiq 8 & Cron | Pure `Sidekiq::Job` hierarchy, weighted queues, and recurring schedule loading. |
| **[07. Redis & Caching](architecture/07-redis-and-caching-setup.md)** | Redis 7 & Caching | Centralized URL resolution, Action Cable Redis adapter, and production `:redis_cache_store`. |
| **[08. File Storage](architecture/08-file-storage-setup.md)** | Active Storage S3 | Remote Amazon S3 enforcement in production, `libvips` processing, and disk fallback elimination. |
| **[09. Email Delivery](architecture/09-email-delivery-and-preview-setup.md)** | ActionMailer & LetterOpener | SMTP relay configuration, mailer host decoupling, and in-browser development previewing. |
| **[10. Security & Abuse](architecture/10-security-and-abuse-prevention-setup.md)** | Rate Limiting & SSL | Rack::Attack on `/admin/login`, CSP nonces, `force_ssl` enforcement with health check exemptions. |
| **[11. Authentication & Admin](architecture/11-authentication-and-admin-setup.md)** | Devise & ActiveAdmin | Enterprise Admin controls (15-min timeout, 3-attempt lockout), Propshaft assets, and Sidekiq SSO. |
| **[12. Testing Infrastructure](architecture/12-testing-infrastructure-setup.md)** | RSpec 7 Modular Setup | Sub-second transactional fixtures (`use_transactional_fixtures = true`), FactoryBot, and Shoulda. |
| **[13. Code Quality](architecture/13-code-quality-and-performance-setup.md)** | Linters & Performance | RuboCop Omakase (0 offenses), Brakeman (0 warnings), Prosopite N+1 query detection. |
| **[14. Docker Production](architecture/14-docker-production-environment-setup.md)** | Multi-Stage Build | Multi-stage slim Dockerfile, non-root user `1000:1000`, Thruster HTTP/2 reverse proxy on port 80. |
| **[15. Docker Development](architecture/15-docker-development-environment-setup.md)** | Compose Environment | Containerized dev stack with Postgres 16, Redis 7, web, sidekiq, and persistent volume caching. |
| **[Bonus: Devise JWT Guide](architecture/devise_jwt_auth_guide.md)** | Future API Auth | Architecture design for adding stateless User JWT auth alongside stateful Admin sessions. |

---

## 3. Staff Engineer Component Reviews

Rigorous, evidence-based technical reviews challenging and validating every layer against official documentation:

| Review Document | Component | Audit Result | Key Takeaway |
| :--- | :--- | :---: | :--- |
| **[01. Ruby Version](reviews/01-ruby-version-review.md)** | Ruby 3.3.6 | **Pass** | Immutable version synchronization with `jemalloc` preloading. |
| **[02. Rails Application](reviews/02-rails-application-review.md)** | Rails 8 Core | **Pass** | Clean Zeitwerk boundaries; explicit UTC timezone consistency. |
| **[03. Dependency Management](reviews/03-dependency-management-review.md)** | Bundler & Gems | **Needs Improvement** | Pagy 43.4.4 has advisory CVE-2026-54659; upgrade to `>= 43.5.6` scheduled. |
| **[04. Database Setup](reviews/04-database-review.md)** | PostgreSQL & DDL | **Pass** | Strong Migrations active; connection pool safely matches worker concurrency. |
| **[05. Environment Config](reviews/05-environment-configuration-review.md)** | `AppConfig` Facade | **Pass** | Centralized facade eliminates raw `ENV` clutter; supports fail-fast `dig!`. |
| **[06. Secrets Management](reviews/06-secrets-management-review.md)** | AES-256 Credentials | **Pass** | Zero secrets committed; `SECRET_KEY_BASE_DUMMY=1` keeps Docker images clean. |
| **[07. Application Initialization](reviews/07-application-initialization-review.md)** | Boot Sequence | **Pass** | Bootsnap precompiled with `-j 1` to bypass QEMU bugs; cold boot under 1.5s. |
| **[08. Development Server](reviews/08-development-server-review.md)** | Puma & Thruster | **Pass** | Thruster terminates port 80 and offloads static assets; Puma internal on 3000. |
| **[09. Testing Infrastructure](reviews/09-testing-infrastructure-review.md)** | RSpec Suite | **Pass** | 55 specs pass in ~1.7s; zero DatabaseCleaner table truncation bottlenecks. |
| **[10. Code Quality](reviews/10-code-quality-review.md)** | Static Analysis | **Pass** | 0 RuboCop offenses, 0 Brakeman warnings, Prosopite N+1 detection in workers. |
| **[11. Authentication Setup](reviews/11-authentication-review.md)** | Devise & ActiveAdmin | **Pass** | 15-min timeout, 3-attempt lockout, IP tracking, Ransack allowlist. |
| **[12. Background Jobs](reviews/12-background-jobs-review.md)** | Sidekiq 8 | **Pass** | Weighted queues (`critical`, `default`, `mailers`, `low`); Sidekiq Web UI SSO. |
| **[13. Redis Setup](reviews/13-redis-review.md)** | Redis 7 & Cable | **Pass** | Centralized URL resolution; live Redis ping probe in health check. |
| **[14. Caching Setup](reviews/14-caching-review.md)** | Cache Strategy | **Pass** | Production `:redis_cache_store`; Propshaft 1-year immutable cache headers. |
| **[15. Security Controls](reviews/15-security-review.md)** | Headers & Throttle | **Pass** | Rack::Attack rate limiting on `/admin/login`; nonced CSP (`script-src`). |
| **[16. Docker Setup](reviews/16-docker-review.md)** | Container Stack | **Pass** | Multi-stage slim build; unprivileged `1000:1000` user; decoupled migrations. |
| **[17. CI/CD Setup](reviews/17-ci-cd-review.md)** | GitHub Actions | **Pass** | Parallel lint/security and test jobs; official Postgres/Redis services; ~40s run. |
| **[18. Production Operations](reviews/18-production-operations-review.md)** | Telemetry & Health | **Pass** | Dual health checks (`/up` shallow, `/up/deep` deep DB/Redis); tagged STDOUT logs. |

---

## 4. Technical Debt & Future Improvements

All backlogged tasks, technical debt items, and version graduation plans are actively tracked in:

👉 **[docs/roadmap/improvements-and-tech-debt.md](roadmap/improvements-and-tech-debt.md)**

Key upcoming items:
- **Pagy Security Upgrade**: Update to `>= 43.5.6` to resolve CVE-2026-54659.
- **Symmetrical Concurrency Fallbacks**: Align Puma thread count and database pool defaults to `5`.
- **ActiveAdmin v4 GA**: Update from `beta21` to final GA release when published.
- **Production Seed Logging**: Add warnings if `INITIAL_ADMIN_EMAIL` is missing during production seeding.
