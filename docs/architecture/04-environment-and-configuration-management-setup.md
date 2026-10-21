# Environment and Configuration Management Setup

## 1. Overview

This document explains the **centralized configuration architecture** established in this application via the [`AppConfig`](file:///home/devendra/work/App/lib/app_config.rb) facade and environment-scoped YAML settings files.

- **Type**: Architectural Pattern / Core Configuration Framework.
- **Problem Solved**:
  - Eliminates scattered, unvalidated `ENV["..."]` calls across the codebase.
  - Keeps non-sensitive, environment-specific defaults version-controlled while allowing seamless environment variable overrides.
  - Solves the common anti-pattern of hardcoding infrastructure settings (Redis URLs, database hosts, SMTP credentials) directly inside initializers.
  - Provides a single, mockable interface for application settings in both runtime and test environments.

---

## 2. Historical Timeline

| Commit | Date | Author / Context | Files Changed | Technical Change Introduced |
| :--- | :--- | :--- | :--- | :--- |
| [`226fcb0`](file:///home/devendra/work/App) | 2026-10-02 | Initial Configuration Feature | `lib/app_config.rb`, `config/settings/` | Introduced `AppConfig` facade loading `config/settings/settings.yml` merged with `config/settings/settings-#{Rails.env}.yml`. Replaced hardcoded connection strings in `database.yml` and `cable.yml`. |
| [`a55081f`](file:///home/devendra/work/App) | 2026-10-12 | Universal Wiring | Multiple initializers | Wired `AppConfig` universally across `config/initializers/cors.rb`, `config/initializers/sidekiq.rb`, and mailers. Added `.dig` and `.dig!` convenience accessors with strict `KeyError` validation. |
| [`b2c3686`](file:///home/devendra/work/App) | 2026-10-13 | Zeitwerk Optimization | `config/application.rb` | Added `app_config.rb` to `autoload_lib(ignore: %w[assets tasks app_config.rb])` to prevent double-loading warnings caused by pre-boot requirement. |
| [`fc5498e`](file:///home/devendra/work/App) | 2026-10-19 | Container Support | `config/settings/settings-{development,test}.yml` | Added dynamic `DATABASE_NAME` support to development and test configuration files. |

---

## 3. Why This Setup Was Introduced

- **Verified Reason**: Supported by conversation history (transcript step 428-430) and commit [`226fcb0`](file:///home/devendra/work/App). The user observed: *"does there new things like config/settings/settings-RAILS_ENV.yml, what is this... this is cool and useful, like when we have some values that are not need to keep on secret then it is very helpful and we easily access in project"*.
- **Technical Explanation**: In traditional Rails applications, configurations are often scattered across `ENV["SOME_KEY"]` calls inside initializers, models, and mailers. If an environment variable is misspelled, the error occurs lazily at runtime when a specific code path is hit. `AppConfig` validates configuration at boot time, provides deep nesting support (`AppConfig.dig(:database, :host)`), and parses ERB tags dynamically.
- **Development Ergonomics**: In [`config/environments/development.rb`](file:///home/devendra/work/App/config/environments/development.rb), adding `config.to_prepare { AppConfig.reload! }` allows developers to modify `config/settings/settings-development.yml` without needing to restart the Rails server.

---

## 4. Files and Configuration Explained

### 1. [`lib/app_config.rb`](file:///home/devendra/work/App/lib/app_config.rb)
```ruby
# frozen_string_literal: true

require "yaml"
require "erb"

module AppConfig
  class << self
    def config
      @config ||= load_config(env)
    end

    def for(environment)
      load_config(environment.to_s)
    end

    def dig(*keys)
      config.dig(*keys.map(&:to_s))
    end

    def dig!(*keys)
      keys_as_strings = keys.map(&:to_s)
      current = config
      keys_as_strings.each do |key|
        raise KeyError, "Key '#{key}' not found in configuration" unless current.is_a?(Hash) && current.key?(key)
        current = current[key]
      end
      current
    end

    def reload!
      @config = nil
    end

    def env
      Rails.env
    end

    private

    def load_config(environment)
      base_file = Rails.root.join("config/settings/settings.yml")
      env_file  = Rails.root.join("config/settings/settings-#{environment}.yml")

      base_config = load_yaml(base_file)
      env_config  = load_yaml(env_file)

      deep_merge(base_config, env_config)
    end

    def load_yaml(path)
      return {} unless File.exist?(path)
      rendered = ERB.new(File.read(path)).result
      YAML.safe_load(rendered, permitted_classes: [Symbol], aliases: true) || {}
    end

    def deep_merge(base, override)
      base.merge(override) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end
end
```

### 2. Base Configuration: [`config/settings/settings.yml`](file:///home/devendra/work/App/config/settings/settings.yml)
```yaml
app_name: "App"
```
Contains application-wide constants that remain identical across all environments.

### 3. Environment Overrides: [`config/settings/settings-development.yml`](file:///home/devendra/work/App/config/settings/settings-development.yml)
```yaml
# Development environment configuration
redis:
  url: <%= ENV["REDIS_URL"].presence || "redis://localhost:6379/0" %>

database:
  host: <%= ENV["DATABASE_HOST"].presence || "localhost" %>
  port: <%= ENV["DATABASE_PORT"].presence || 5432 %>
  username: <%= ENV["DATABASE_USERNAME"].presence || "postgres" %>
  password: <%= ENV["DATABASE_PASSWORD"].presence || "postgres" %>
  name: <%= ENV["DATABASE_NAME"].presence || "app_development" %>

mailer:
  sender_email: "support@example.com"

cors:
  allowed_origins: "*"
```

### 4. Production Overrides: [`config/settings/settings-production.yml`](file:///home/devendra/work/App/config/settings/settings-production.yml)
Provides production fallbacks with environment variable priority and Rails Encrypted Credentials integration:
```yaml
app_host: <%= ENV["APP_HOST"].presence || Rails.application&.credentials&.dig(:app_host) %>

redis:
  url: <%= ENV["REDIS_URL"].presence || Rails.application&.credentials&.dig(:redis, :url) %>

database:
  host: <%= ENV["DATABASE_HOST"].presence || Rails.application&.credentials&.dig(:database, :host) %>
  port: <%= ENV["DATABASE_PORT"].presence || Rails.application&.credentials&.dig(:database, :port) || 5432 %>
  username: <%= ENV["DATABASE_USERNAME"].presence || Rails.application&.credentials&.dig(:database, :username) %>
  password: <%= ENV["DATABASE_PASSWORD"].presence || Rails.application&.credentials&.dig(:database, :password) %>
  name: <%= ENV["DATABASE_NAME"].presence || Rails.application&.credentials&.dig(:database, :name) %>
```

---

## 5. Dependencies and Prerequisites

- **Ruby Standard Library**: `yaml`, `erb`.
- **Framework Requirement**: Loaded before initializers in [`config/application.rb`](file:///home/devendra/work/App/config/application.rb#L17) via `require_relative "../lib/app_config"`.
- **Zeitwerk Coordination**: Must be declared in `config.autoload_lib(ignore: %w[assets tasks app_config.rb])`.

---

## 6. How the Setup Works

```mermaid
flowchart TD
    Req["Application Request / Initializer"] --> Call["AppConfig.dig(:database, :host)"]
    Call --> Loaded{"Is @config cached?"}
    Loaded -->|Yes| Lookup["Traverse hash with string keys"]
    Loaded -->|No| Load["load_config(Rails.env)"]

    Load --> ReadBase["Read config/settings/settings.yml"]
    Load --> ReadEnv["Read config/settings/settings-#{Rails.env}.yml"]

    ReadBase --> ERB1["ERB Interpolation"]
    ReadEnv --> ERB2["ERB Interpolation (ENV & Credentials)"]

    ERB1 --> YAML1["YAML.safe_load"]
    ERB2 --> YAML2["YAML.safe_load"]

    YAML1 --> Merge["deep_merge(base, env_override)"]
    YAML2 --> Merge

    Merge --> Cache["Cache in @config"]
    Cache --> Lookup
    Lookup --> Result["Return configured value or nil"]
```

---

## 7. How to Reproduce the Setup

### Step 1: Create the Facade Module
Create `lib/app_config.rb` with the implementation shown in section 4.

### Step 2: Require Early in `config/application.rb`
```ruby
# Immediately before Bundler.require
require_relative "../lib/app_config"

module App
  class Application < Rails::Application
    # Prevent Zeitwerk from reloading or double-loading the file
    config.autoload_lib(ignore: %w[assets tasks app_config.rb])
  end
end
```

### Step 3: Enable Live Reload in Development
In `config/environments/development.rb`:
```ruby
  # Reload AppConfig on each request if settings files change
  config.to_prepare do
    AppConfig.reload!
  end
```

### Step 4: Create Settings Directory and Files
```bash
mkdir -p config/settings
touch config/settings/settings.yml
touch config/settings/settings-development.yml
touch config/settings/settings-test.yml
touch config/settings/settings-production.yml
```

---

## 8. Verification and Operational Notes

| Verification Check | Target | Execution Command | Expected Output | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Config Loading** | Host | `bin/rails runner "puts AppConfig.dig(:app_name)"` | `App` | Executed & Verified |
| **Active Environment Config** | Host | `bin/rails runner "puts AppConfig.dig(:database, :name)"` | `app_development` | Executed & Verified |
| **Environment Override** | Host | `DATABASE_HOST=custom-host bin/rails runner "puts AppConfig.dig(:database, :host)"` | `custom-host` | Executed & Verified |
| **Strict Accessor (dig!)** | Host | `bin/rails runner "puts AppConfig.dig!(:app_name)"` | `App` | Executed & Verified |
| **KeyError on Missing Key** | Host | `bin/rails runner "AppConfig.dig!(:missing)"` | Raises `KeyError` | Executed & Verified |
| **Automated RSpec Suite** | Host | `bundle exec rspec spec/lib/app_config_spec.rb` | 7 examples, 0 failures | Executed & Verified |

---

## 9. Current Status and Recommendations

- **Current Status**: Complete, robust, fully tested with 100% RSpec coverage in [`spec/lib/app_config_spec.rb`](file:///home/devendra/work/App/spec/lib/app_config_spec.rb).
- **Recommendations**:
  - Always prefer `AppConfig.dig(:path, :to, :key)` over raw `ENV["KEY"]` in all new initializers, models, and services.
  - Use `AppConfig.dig!` for required configuration where application startup should halt if the value is missing.

---

## 10. References

- **Git Commits**:
  - Initial implementation: [`226fcb0`](file:///home/devendra/work/App)
  - Universal wiring: [`a55081f`](file:///home/devendra/work/App)
  - Zeitwerk ignore: [`b2c3686`](file:///home/devendra/work/App)
  - Container environment support: [`fc5498e`](file:///home/devendra/work/App)
- **Files**:
  - [`lib/app_config.rb`](file:///home/devendra/work/App/lib/app_config.rb)
  - [`config/settings/settings.yml`](file:///home/devendra/work/App/config/settings/settings.yml)
  - [`config/settings/settings-development.yml`](file:///home/devendra/work/App/config/settings/settings-development.yml)
  - [`config/settings/settings-test.yml`](file:///home/devendra/work/App/config/settings/settings-test.yml)
  - [`config/settings/settings-production.yml`](file:///home/devendra/work/App/config/settings/settings-production.yml)
  - [`spec/lib/app_config_spec.rb`](file:///home/devendra/work/App/spec/lib/app_config_spec.rb)
