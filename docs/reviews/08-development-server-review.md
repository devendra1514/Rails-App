# Staff Engineer Review: Web Server & Process Architecture

## 1. Scope and Current Implementation

This review assesses the application web server configuration, reverse proxy acceleration, concurrency tuning, and process orchestration across [`config/puma.rb`](file:///home/devendra/work/App/config/puma.rb), [`bin/thrust`](file:///home/devendra/work/App/bin/thrust), and [`Dockerfile`](file:///home/devendra/work/App/Dockerfile).

### Current Implementation Details
- **Application Server**: Puma (v5+ / v6+).
  - Thread concurrency: `threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)`.
  - Process concurrency: Controlled via `ENV["WEB_CONCURRENCY"]` (defaults to single-mode for container memory efficiency).
  - Internal Port: Listens on `ENV.fetch("PORT", 3000)`.
- **HTTP/2 & Caching Accelerator**: Thruster ([`gem "thruster"`](https://github.com/basecamp/thruster)).
  - Production entrypoint: `CMD ["./bin/thrust", "./bin/rails", "server"]`.
  - External Port: Thruster binds to port `80`.
  - Proxy Architecture: Thruster acts as a high-performance, zero-config reverse proxy written in Go that sits in front of Puma. It terminates external connections on Port 80, serves precompiled static assets with gzip/brotli compression, offloads file caching, and forwards dynamic requests to Puma on Port 3000.

---

## 2. Historical Context

- **Commit [`be0edb0`](file:///home/devendra/work/App) (2026-09-29)**: Rails default Puma configuration and Thruster command in `Dockerfile`.
- **Commit [`aabf285`](file:///home/devendra/work/App) (2026-10-10)**: Thread and DB pool alignment.
- **Commit [`0e666e4`](file:///home/devendra/work/App) (2026-10-19)**: Development container mapped port 3000 directly for easy debugging.

---

## 3. Engineering Assessment

### A. Thruster vs Traditional Nginx
Traditionally, Rails deployments required running an Nginx container or sidecar alongside Puma to handle SSL, gzip compression, and static asset serving.
- **Advantages of Thruster in Rails 8**:
  1. Runs inside the same container as Puma, eliminating multi-container pod/compose complexity.
  2. Binds directly to port 80 and provides HTTP/2 multiplexing out of the box.
  3. Caches static assets in memory and disk without requiring custom Nginx configurations.

### B. Port Confusion Risk
Because Thruster listens on port 80 and forwards to Puma on port 3000, passing `PORT=3000` to a production container causes Thruster to listen on 3000, breaking standard `80:80` Docker port mappings. This operational detail must be documented for operators.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **SRV-01** | **Pass** | Low | Thruster eliminates need for separate Nginx container | [`Dockerfile:76-77`](file:///home/devendra/work/App/Dockerfile#L76-L77) exposes port 80 and executes `./bin/thrust`. |
| **SRV-02** | **Pass** | Low | Puma thread pool defaults to 3 threads | Well-suited for average CPU/memory quotas on cloud VMs (e.g., AWS `t3.micro`/`t3.small`). |

---

## 5. Recommended Approach

The Puma + Thruster architecture represents the modern Rails 8 standard for containerized web hosting. **Keep unchanged.**

---

## 6. Standard Approach for Future Projects

- Use Thruster as the default container proxy for Rails 8+.
- Do not set `PORT=3000` in production containers; leave Thruster on port 80.
- Scale concurrency horizontally across containers rather than setting high `WEB_CONCURRENCY` per container.

---

## 7. Verification Checklist

- [x] Thruster launches Puma and proxies requests from port 80 to 3000.
- [x] Static assets receive `Cache-Control` and gzip/brotli compression headers.
- [x] Puma thread pool scales when `RAILS_MAX_THREADS` is set.

---

## 8. References
- Thruster Documentation: https://github.com/basecamp/thruster
- Puma Configuration Documentation: https://puma.io/puma/
