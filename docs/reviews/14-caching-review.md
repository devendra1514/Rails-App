# Staff Engineer Review: Caching Strategy & HTTP Acceleration

## 1. Scope and Current Implementation

This review assesses application caching, key eviction policies, HTTP static asset caching, and ETag invalidation across [`config/environments/production.rb`](file:///home/devendra/work/App/config/environments/production.rb), [`config/environments/development.rb`](file:///home/devendra/work/App/config/environments/development.rb), and [`app/controllers/application_controller.rb`](file:///home/devendra/work/App/app/controllers/application_controller.rb).

### Current Implementation Details
- **Production Cache Store**:
  - [`config/environments/production.rb:50`](file:///home/devendra/work/App/config/environments/production.rb#L50):
    ```ruby
    config.cache_store = :redis_cache_store, { url: AppConfig.dig(:redis, :url) }
    ```
- **Development Cache Store**:
  - Controlled dynamically via `bin/rails dev:cache` (creating `tmp/caching-dev.txt`).
  - When enabled: `:memory_store` with 64 MB limit.
  - When disabled: `:null_store`.
- **Test Cache Store**:
  - `:null_store` to prevent state leakage between examples.
- **HTTP & Static Asset Caching**:
  - `config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }`.
  - Thruster serves assets from memory and disk cache with gzip and brotli compression.
  - Propshaft computes SHA-1 asset digests, enabling safe 1-year immutable caching.
- **Importmap ETag Invalidation**:
  - [`app/controllers/application_controller.rb:6`](file:///home/devendra/work/App/app/controllers/application_controller.rb#L6) includes `stale_when_importmap_changes`, ensuring browser ETags invalidate automatically whenever `config/importmap.rb` changes.

---

## 2. Historical Context

- **Commit [`be0edb0`](file:///home/devendra/work/App) (2026-09-29)**: Rails default caching templates.
- **Commit [`1ebe358`](file:///home/devendra/work/App) (2026-10-10)**: Configured `:redis_cache_store` in production.
- **Commit [`a55081f`](file:///home/devendra/work/App) (2026-10-12)**: Connected Redis cache store URL to `AppConfig.dig(:redis, :url)`.

---

## 3. Engineering Assessment

### A. Asset Fingerprinting & Long-Lived Caching
Propshaft's digest calculation combined with Thruster's HTTP accelerator provides zero-maintenance, high-performance static asset serving. Assets can be cached aggressively for 1 year by CDNs and browsers because any code change generates a new digest URL.

### B. Redis Cache Driver
Using `:redis_cache_store` in production allows multiple Puma workers and multiple container instances to share a centralized cache pool, enabling distributed fragment caching and cross-worker throttling.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **CACHE-01** | **Pass** | Low | Importmap changes invalidate browser ETags automatically | [`app/controllers/application_controller.rb:6`](file:///home/devendra/work/App/app/controllers/application_controller.rb#L6). |
| **CACHE-02** | **Pass** | Low | Development cache is toggleable via standard Rails CLI | `bin/rails dev:cache` toggles memory cache. |

---

## 5. Recommended Approach

The caching architecture is modern, performant, and follows Rails 8 standards. **Keep unchanged.**

---

## 6. Standard Approach for Future Projects

- Use `:redis_cache_store` for multi-container deployments.
- Set 1-year cache control headers on digested assets.
- Use `stale_when_importmap_changes` when using Importmap Rails.

---

## 7. Verification Checklist

- [x] `Rails.cache.write` and `Rails.cache.read` function in production.
- [x] Static assets return `Cache-Control: public, max-age=31536000`.
- [x] `bin/rails dev:cache` toggles caching in development.

---

## 8. References
- Rails Caching Guide: https://guides.rubyonrails.org/caching_with_rails.html
- Propshaft Asset Pipeline: https://github.com/rails/propshaft
