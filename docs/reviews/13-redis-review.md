# Staff Engineer Review: Redis Infrastructure & Cable Adapter

## 1. Scope and Current Implementation

This review assesses the centralized Redis configuration, connection pooling, pub/sub infrastructure, and health verification across [`config/cable.yml`](file:///home/devendra/work/App/config/cable.yml), [`config/initializers/sidekiq.rb`](file:///home/devendra/work/App/config/initializers/sidekiq.rb), and [`config/environments/production.rb`](file:///home/devendra/work/App/config/environments/production.rb).

### Current Implementation Details
- **Engine**: Redis 7 (Alpine in containerized environments).
- **Client Driver**: `gem "redis"`.
- **Centralized Resolution**:
  - All components query the same single source of truth: `AppConfig.dig(:redis, :url)`.
  - Development default: `redis://localhost:6379/0`.
  - Test default: `redis://localhost:6379/0` (isolated via fake adapter in specs).
  - Production fallback: Resolves from `ENV["REDIS_URL"]` or decrypted `production.yml.enc`.
- **Consumer Stacks**:
  1. **Background Processing**: Sidekiq client and server.
  2. **WebSocket Pub/Sub**: Action Cable ([`config/cable.yml`](file:///home/devendra/work/App/config/cable.yml)) uses `:redis` adapter.
  3. **Application Cache**: Rails cache store (`:redis_cache_store`).
  4. **Deep Health Check**: Probed in real-time via `Sidekiq.redis { |c| c.ping }` in [`HealthController`](file:///home/devendra/work/App/app/controllers/health_controller.rb).

---

## 2. Historical Context

- **Commit [`5dc08ae`](file:///home/devendra/work/App) (2026-09-29)**: Standardized on Redis for queue, cable, and cache.
- **Commit [`cd585fe`](file:///home/devendra/work/App) (2026-09-30)**: Sidekiq client/server Redis wiring.
- **Commit [`1ebe358`](file:///home/devendra/work/App) (2026-10-10)**: Redis cache store in production.
- **Commit [`6df2174`](file:///home/devendra/work/App) (2026-10-21)**: Active Redis ping verification in deep health check.

---

## 3. Engineering Assessment

### A. Single URL vs Separate Namespaces
In enterprise architectures, sharing a single Redis database instance between ephemeral cache data and persistent Sidekiq queues can create risk: an aggressive `Rails.cache.clear` could inadvertently flush Sidekiq job queues if both operate on the same keyspace.
- **Current Mitigation**: Sidekiq and Action Cable use explicit key prefixes. 
- **Production Recommendation**: When scaling to high load, point `cache_store` to a different database index (e.g., `/1` for cache, `/0` for queues) or a distinct Redis instance with an `allkeys-lru` eviction policy.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **REDIS-01** | **Pass** | Low | Universal configuration facade guarantees URL consistency | Cable, Cache, and Sidekiq all read from `AppConfig.dig(:redis, :url)`. |
| **REDIS-02** | **Pass** | Medium | Active Redis ping in health check verifies connection vitality | [`app/controllers/health_controller.rb:33`](file:///home/devendra/work/App/app/controllers/health_controller.rb#L33) calls `Sidekiq.redis { |conn| conn.ping }`. |
| **REDIS-03** | **Optional** | Low | Cache and Sidekiq share the same Redis database index by default | In `settings-production.yml`, `REDIS_URL` defaults to index `/0`. Separating cache to `/1` avoids keyspace collision. |

---

## 5. Recommended Approach

The Redis integration is solid and well-tested. As a future enhancement when traffic increases, split `REDIS_URL` and `REDIS_CACHE_URL` in `settings-production.yml`.

---

## 6. Standard Approach for Future Projects

- Route Redis URLs through a central configuration facade.
- Separate cache and queue databases to prevent cache evictions from deleting jobs.
- Probe Redis ping in health check endpoints.

---

## 7. Verification Checklist

- [x] Sidekiq connects and processes jobs via Redis.
- [x] Action Cable boots with Redis adapter.
- [x] `/up/deep` returns 200 when Redis is alive and 503 when Redis is stopped.

---

## 8. References
- Redis Documentation: https://redis.io/docs/
- Action Cable Redis Adapter: https://guides.rubyonrails.org/action_cable_overview.html
