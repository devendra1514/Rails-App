# Staff Engineer Review: Ruby Runtime & Version Setup

## 1. Scope and Current Implementation

This review assesses the selection, synchronization, and enforcement of the **Ruby runtime environment** across local development, containerized environments, CI runners, and production Docker builds.

### Current Implementation Details
- **Ruby Version**: `3.3.6` (revision `p108`).
- **Files Enforcing Version**:
  - [`.ruby-version`](file:///home/devendra/work/App/.ruby-version): Contains `3.3.6`. Used by version managers (`rbenv`, `rvm`, `asdf`, `mise`).
  - [`Gemfile`](file:///home/devendra/work/App/Gemfile#L3): Contains `ruby file: ".ruby-version"`. Directs Bundler to read the single source of truth from `.ruby-version`.
  - [`Gemfile.lock`](file:///home/devendra/work/App/Gemfile.lock): Records `RUBY VERSION: ruby 3.3.6p108`.
  - [`Dockerfile`](file:///home/devendra/work/App/Dockerfile#L11): `ARG RUBY_VERSION=3.3.6`. Base image: `ruby:3.3.6-slim`.
  - [`Dockerfile.dev`](file:///home/devendra/work/App/Dockerfile.dev#L1): `ARG RUBY_VERSION=3.3.6`. Base image: `ruby:3.3.6-slim`.
  - [`.github/workflows/ci.yml`](file:///home/devendra/work/App/.github/workflows/ci.yml#L19): Sets `ruby-version: "3.3.6"`.
- **Runtime Performance Flags**:
  - Memory Allocator: `libjemalloc2` enabled via `LD_PRELOAD="/usr/local/lib/libjemalloc.so"` in both production and development Dockerfiles.
  - JIT Compilation: YJIT enabled in development container (`RUBY_YJIT_ENABLE=1`).

---

## 2. Historical Context

- **Commit [`be0edb0`](file:///home/devendra/work/App) (2026-09-29)**: Initialized Rails app. `.ruby-version` set to `3.3.6` and `Dockerfile` set `ARG RUBY_VERSION=3.3.6`. However, `Gemfile` omitted a `ruby` directive, allowing systems running older Ruby versions (such as RVM default `3.2.2`) to execute `bundle exec` without complaint, leading to subtle lockfile divergences.
- **Commit [`bc744aa`](file:///home/devendra/work/App) (2026-10-13)**: Audit remediation synchronized the version across all layers. Added `ruby file: ".ruby-version"` to `Gemfile` and regenerated `Gemfile.lock` on Ruby 3.3.6, creating an immutable single source of truth.
- **Commit [`0e666e4`](file:///home/devendra/work/App) (2026-10-19)**: Dedicated development Dockerfile added with identical Ruby 3.3.6 base and jemalloc support.

---

## 3. Engineering Assessment

### A. Correctness & Compatibility
The single-source-of-truth pattern (`ruby file: ".ruby-version"`) supported natively in Bundler 2.4+ ensures that any developer or CI runner executing Bundler with an incompatible Ruby version is immediately halted with a fatal error.

### B. Standards and Conventions
This setup follows canonical Ruby community standards. Using `.ruby-version` avoids maintaining duplicate version strings across `.ruby-version` and `Gemfile`.

### C. Performance & Resource Management
Enabling `libjemalloc2` in containerized environments is an industry best practice for MRI Ruby. It dramatically reduces memory fragmentation caused by multi-threaded Puma workers and memory-intensive background tasks.

---

## 4. Findings

| ID | Assessment | Severity | Finding | Evidence |
| :--- | :--- | :---: | :--- | :--- |
| **RUBY-01** | **Pass** | Low | YJIT is enabled in Docker dev but relies on Ruby 3.3 default in production | `Dockerfile.dev` exports `RUBY_YJIT_ENABLE=1`; in `Dockerfile` production, YJIT is enabled by default in Ruby 3.3+ when built with `--enable-yjit`. Explicit declaration is recommended for predictability. |
| **RUBY-02** | **Pass** | Low | `jemalloc` path symlink is architecture-dependent | `Dockerfile:20` uses `ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so`, which correctly handles both x86_64 and aarch64 (ARM). |

---

## 5. Recommended Approach

The existing implementation is production-grade and should **remain unchanged**. For future clarity, explicitly export `RUBY_YJIT_ENABLE=1` in `Dockerfile` as well.

---

## 6. Standard Approach for Future Projects

1. Place `.ruby-version` at the repository root.
2. Add `ruby file: ".ruby-version"` in `Gemfile`.
3. Parameterize all Dockerfiles with `ARG RUBY_VERSION=...` matching `.ruby-version`.
4. Preload `jemalloc` on Debian slim images.

---

## 7. Verification Checklist

- [x] `.ruby-version` matches `Gemfile.lock` (`ruby 3.3.6p108`).
- [x] `Dockerfile` builds on `ruby:3.3.6-slim`.
- [x] `Dockerfile.dev` builds on `ruby:3.3.6-slim`.
- [x] CI runner executes on `3.3.6`.
- [x] Memory allocator `jemalloc` loaded without warning.

---

## 8. References
- Official Bundler Ruby directive: https://bundler.io/man/gemfile.5.html
- Ruby 3.3 Release Notes & YJIT: https://www.ruby-lang.org/en/news/2023/12/25/ruby-3-3-0-released/
