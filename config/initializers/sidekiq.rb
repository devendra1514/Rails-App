# frozen_string_literal: true

# Sidekiq configuration for all environments
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
