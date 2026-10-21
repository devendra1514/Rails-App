# Devise & JWT Hybrid Authentication Guide (Admin & User)

A concise guide for implementing **Devise Session Auth (Admin)** and **Devise + JWT Stateless Auth (User)** in Ruby on Rails.

---

## 1. Architecture Overview

* **Admin (`:admin` scope)**: Stateful session cookie auth (`ActionController::Base`), CSRF protected, HTML dashboard.
* **User (`:user` scope)**: Stateless JWT auth (`ActionController::API`), `Authorization: Bearer <token>` header, JSON API.
* **How separation works**: Under the hood, Warden distinguishes tokens by the **`scp` (scope)** claim in the JWT (`scp: "user"` vs `scp: "admin"`).

---

## 2. Database Migrations

Only `User` needs the `jti` column for token revocation. `Admin` uses standard Devise tables.

```ruby
class AddJtiToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :jti, :string, null: false
    add_index  :users, :jti, unique: true
  end
end
```

---

## 3. Model Configuration

### `app/models/admin.rb` (Session-Based)
```ruby
class Admin < ApplicationRecord
  # Do NOT include :jwt_authenticatable
  devise :database_authenticatable, :validatable,
         :timeoutable, :lockable, :trackable,
         timeout_in: 15.minutes,         # Session timeout (inactivity)
         maximum_attempts: 3,            # Strict lockout
         unlock_strategy: :email         # Unlock via email link
end
```

### `app/models/user.rb` (Stateless JWT)
```ruby
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Do NOT include :timeoutable (stateless JWT has no session store)
  devise :database_authenticatable, :registerable, :validatable,
         :lockable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: self,
         maximum_attempts: 5,            # Relaxed lockout
         unlock_strategy: :time,
         unlock_in: 30.minutes

  # Immediately invalidate active JWTs if user account gets locked
  def self.jwt_revoked?(payload, user)
    super || !user.active_for_authentication?
  end
end
```

---

## 4. Devise Initializer (`config/initializers/devise.rb`)

Keep navigational formats for Admin HTML views, and target **only** User endpoints for JWT dispatch/revocation:

```ruby
Devise.setup do |config|
  # Preserves HTML redirects & flash messages for Admin
  config.navigational_formats = ['*/*', :html]

  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
    jwt.expiration_time = 1.day.to_i # Replaces timeoutable for API users

    # ONLY dispatch tokens for User sign_in
    jwt.dispatch_requests = [
      ['POST', %r{^/api/v1/users/sign_in$}]
    ]

    # ONLY revoke tokens on User sign_out
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/v1/users/sign_out$}]
    ]
  end
end
```

---

## 5. Routes (`config/routes.rb`)

```ruby
Rails.application.routes.draw do
  # Admin Web (HTML / Sessions)
  devise_for :admins, path: 'admins'
  namespace :admin do
    root to: 'dashboard#index'
  end

  # User API (JSON / JWT)
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      devise_for :users,
                 path: 'users',
                 controllers: {
                   sessions: 'api/v1/users/sessions',
                   registrations: 'api/v1/users/registrations'
                 }
    end
  end
end
```

---

## 6. Controller Handling

### Admin Controller (Stateful)
```ruby
class Admin::DashboardController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :authenticate_admin!

  def index
    # current_admin is read from session cookie
  end
end
```

### User API Controller (Stateless)
```ruby
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_user!
  # current_user is decoded from Authorization: Bearer <token>
end
```

### Shared Controller (Accessible by User OR Admin)
Use non-banging `warden.authenticate` to test scopes sequentially without premature halts:

```ruby
class Api::V1::SharedController < ActionController::API
  before_action :authenticate_user_or_admin!

  def authenticate_user_or_admin!
    @current_actor = warden.authenticate(scope: :user) || warden.authenticate(scope: :admin)
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_actor
  end

  attr_reader :current_actor
end
```

---

## 7. CORS Configuration (`config/initializers/cors.rb`)

Must expose `Authorization` header so API clients can access the JWT from login responses:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '/api/*',
      headers: :any,
      expose: ['Authorization'],
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

---

## 8. Devise Module Support Matrix

| Feature | Admin (`:admin`) | User (`:user`) | Behavior / Solution |
| :--- | :--- | :--- | :--- |
| **Auth Transport** | Session Cookie | `Authorization: Bearer <token>` | Automatic via Warden scopes |
| **`:timeoutable`** | Supported | Not supported | Admin uses session; User uses `jwt.expiration_time` |
| **`:lockable`** | Supported | Supported | DB tracks attempts. Use `jwt_revoked?` to block existing JWTs |
| **`:trackable`** | Supported | Supported | Updates IP and counters on login for both |
| **`:rememberable`**| Supported | Not needed | Handled by client-side secure token storage |
| **CSRF Protection**| Required | Not needed | API requests rely on Bearer tokens |
