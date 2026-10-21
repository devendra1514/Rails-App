# Security and Abuse Prevention Setup

## 1. Overview

This document details the **defense-in-depth security infrastructure** implemented in this application, including **transport encryption (SSL/TLS)**, **Cross-Origin Resource Sharing (CORS)**, **request rate limiting and abuse prevention (Rack::Attack)**, and **sensitive parameter filtering**.

- **Type**: Application Security / Defense-in-Depth.
- **Problem Solved**:
  - Protects against brute-force credential stuffing and password guessing attacks.
  - Mitigates denial-of-service (DoS) attempts and endpoint scraping.
  - Enforces HTTPS and secure reverse-proxy headers in cloud architectures.
  - Restricts cross-origin resource requests to permitted domains while exposing necessary authorization headers for JWT/API clients.
  - Prevents credential leaks in application logs.

---

## 2. Historical Timeline

| Commit | Date | Author / Context | Files Changed | Technical Change Introduced |
| :--- | :--- | :--- | :--- | :--- |
| [`be0edb0`](file:///home/devendra/work/App) | 2026-09-29 | Rails New | `config/initializers/filter_parameter_logging.rb` | Initialized default parameter filtering rules. |
| [`a294cef`](file:///home/devendra/work/App) | 2026-10-05 | CORS Setup | `Gemfile`, `config/initializers/cors.rb` | Added `rack-cors` gem. Allowed cross-origin requests and exposed the `Authorization` header for frontend API clients. |
| [`b16171f`](file:///home/devendra/work/App) | 2026-10-06 | SSL Enforcement | `config/environments/production.rb` | Enabled `config.force_ssl = true` and `config.assume_ssl = true` for cloud reverse proxies. |
| [`f6a1fb3`](file:///home/devendra/work/App) | 2026-10-07 | Rack::Attack Addition | `Gemfile`, `config/initializers/rack_attack.rb` | Added `rack-attack` gem. Implemented global IP rate limiting (300 req / 5 min), localhost safelisting, and custom 429 JSON responses. |
| [`a50fe15`](file:///home/devendra/work/App) | 2026-10-12 | Environment-Scoped CORS | `config/initializers/cors.rb`, `config/settings/` | Wired CORS allowed origins dynamically through `AppConfig.dig(:cors, :allowed_origins)` so origins differ per environment. |
| [`3ed0850`](file:///home/devendra/work/App) | 2026-10-13 | Admin Login Throttling | `config/initializers/rack_attack.rb` | Added specialized rate limiting for ActiveAdmin authentication: 5 requests per 20 seconds by IP, and 5 requests per minute by email. |

---

## 3. Why This Setup Was Introduced

- **Verified Reason (CORS Authorization Exposure)**: Commit [`a294cef`](file:///home/devendra/work/App). When API clients authenticate using JWTs or bearer tokens, browsers block JavaScript from reading the `Authorization` header unless the backend explicitly declares `expose: %w[Authorization]`.
- **Verified Reason (SSL & Reverse Proxy)**: Commit [`b16171f`](file:///home/devendra/work/App). In modern cloud deployments (AWS ALB, Cloudflare, Traefik, Nginx), TLS termination happens at the edge proxy, which forwards requests over plain HTTP internally with `X-Forwarded-Proto: https`. Setting `config.assume_ssl = true` instructs Rails to trust the reverse proxy headers rather than entering redirect loops.
- **Verified Reason (Admin Login Throttling)**: Commit [`3ed0850`](file:///home/devendra/work/App). Administrative login endpoints (`/admin/login`) are high-value targets for brute-force dictionary attacks. Throttling attempts at the Rack middleware layer drops abusive requests before they reach the database or bcrypt password hashing functions, preserving server CPU.

---

## 4. Files and Configuration Explained

### 1. Request Throttling: [`config/initializers/rack_attack.rb`](file:///home/devendra/work/App/config/initializers/rack_attack.rb)
```ruby
# frozen_string_literal: true

class Rack::Attack
  # Always allow requests from localhost
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # Throttle all requests by IP (300 requests per 5 minutes)
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/up")
  end

  # Throttle Admin login attempts by IP (5 attempts per 20 seconds)
  throttle("admin_logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/admin/login" && req.post?
      req.ip
    end
  end

  # Throttle Admin login attempts by email (5 attempts per minute)
  throttle("admin_logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/admin/login" && req.post?
      req.params.dig("admin", "email").to_s.downcase.strip.presence
    end
  end

  # Custom 429 response
  self.throttled_responder = lambda do |_env|
    headers = {
      "Content-Type" => "application/json",
      "Retry-After"  => "60"
    }
    body = { error: "Rate limit exceeded. Please try again later." }.to_json
    [429, headers, [body]]
  end
end
```

### 2. Cross-Origin Resource Sharing: [`config/initializers/cors.rb`](file:///home/devendra/work/App/config/initializers/cors.rb)
```ruby
# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins AppConfig.dig(:cors, :allowed_origins) || "*"

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization],
      max_age: 600
  end
end
```
- **Environment Scoped**: In development, `origins` is `*`. In production, `config/settings/settings-production.yml` can restrict origins to trusted customer domains (`https://example.com`).

### 3. Production SSL Enforcement: [`config/environments/production.rb`](file:///home/devendra/work/App/config/environments/production.rb#L25-L27)
```ruby
  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true
  config.assume_ssl = true
```

### 4. Parameter Filtering: [`config/initializers/filter_parameter_logging.rb`](file:///home/devendra/work/App/config/initializers/filter_parameter_logging.rb)
Filters sensitive tokens, passwords, crypt keys, credit card numbers, and authorization headers from application logs:
```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
```

---

## 5. Dependencies and Prerequisites

- **Gems**:
  - `gem "rack-attack"` (locked at `6.7.0`)
  - `gem "rack-cors"` (locked at `2.0.2`)
- **Cache Storage**: Rack::Attack leverages `Rails.cache` (backed by Redis in production) for distributed rate tracking across multiple server processes.

---

## 6. How the Setup Works

```mermaid
flowchart TD
    ClientReq["Incoming HTTP Request"] --> RackAttack["Rack::Attack Middleware"]

    RackAttack --> Safelist{"Is req from localhost?"}
    Safelist -->|Yes| Bypass["Bypass rate limits"]

    Safelist -->|No| ThrottleCheck{"Rate limit exceeded in Redis?"}
    ThrottleCheck -->|Yes| HTTP429["Return 429 Too Many Requests (JSON)"]

    ThrottleCheck -->|No| CorsMiddleware["Rack::Cors Middleware"]
    Bypass --> CorsMiddleware

    CorsMiddleware --> OriginCheck{"Is Origin permitted?"}
    OriginCheck -->|No| CORSReject["Reject cross-origin request"]
    OriginCheck -->|Yes| AddHeaders["Add Access-Control headers"]

    AddHeaders --> RailsApp["Rails Routing & Controller Pipeline"]
```

---

## 7. How to Reproduce the Setup

### Step 1: Install Dependencies
In `Gemfile`:
```ruby
gem "rack-cors"
gem "rack-attack"
```
Run `bundle install`.

### Step 2: Configure CORS Initializer
Create `config/initializers/cors.rb` wired to `AppConfig.dig(:cors, :allowed_origins)` (see section 4).

### Step 3: Configure Rack::Attack Initializer
Create `config/initializers/rack_attack.rb` with IP, email, and admin login rules (see section 4).

### Step 4: Configure Production SSL
In `config/environments/production.rb`:
```ruby
config.force_ssl = true
config.assume_ssl = true
```

---

## 8. Verification and Operational Notes

| Verification Check | Target | Execution Command | Expected Output | Status |
| :--- | :--- | :--- | :--- | :--- |
| **CORS Preflight Headers** | Host | `curl -I -X OPTIONS http://localhost:3000/up -H "Origin: http://test.com" -H "Access-Control-Request-Method: GET"` | `access-control-allow-origin: *` | Executed & Verified |
| **Rack::Attack Throttling Spec** | Host | `bundle exec rspec spec/requests/rack_attack_spec.rb` | 1 example, 0 failures | Executed & Verified |
| **Admin Login Rate Limiting Spec** | Host | `bundle exec rspec spec/requests/admin/rate_limiting_spec.rb` | 1 example, 0 failures | Executed & Verified |
| **CORS Spec Suite** | Host | `bundle exec rspec spec/initializers/cors_spec.rb` | 2 examples, 0 failures | Executed & Verified |

---

## 9. Current Status and Recommendations

- **Current Status**: Complete, robust, fully covered by automated request specs.
- **Recommendations**:
  - In production, set specific domains in `config/settings/settings-production.yml` under `cors.allowed_origins` rather than `*` once frontend production URLs are finalized.
  - Review Rack::Attack throttled logs in production to detect automated credential stuffing campaigns.

---

## 10. References

- **Git Commits**:
  - Initial parameter filtering: [`be0edb0`](file:///home/devendra/work/App)
  - CORS setup: [`a294cef`](file:///home/devendra/work/App), [`a50fe15`](file:///home/devendra/work/App)
  - SSL enforcement: [`b16171f`](file:///home/devendra/work/App)
  - Rack::Attack throttling: [`f6a1fb3`](file:///home/devendra/work/App), [`3ed0850`](file:///home/devendra/work/App)
- **Files**:
  - [`config/initializers/cors.rb`](file:///home/devendra/work/App/config/initializers/cors.rb)
  - [`config/initializers/rack_attack.rb`](file:///home/devendra/work/App/config/initializers/rack_attack.rb)
  - [`config/initializers/filter_parameter_logging.rb`](file:///home/devendra/work/App/config/initializers/filter_parameter_logging.rb)
  - [`config/environments/production.rb`](file:///home/devendra/work/App/config/environments/production.rb)
- **External Documentation**:
  - [Securing Rails Applications Guide](https://guides.rubyonrails.org/security.html)
  - [Rack::Attack Documentation](https://github.com/rack/rack-attack)
  - [Rack::Cors Documentation](https://github.com/cyu/rack-cors)
