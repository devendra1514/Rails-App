# frozen_string_literal: true

class HealthController < ActionController::API
  def show
    db_connected = check_database
    redis_connected = check_redis

    all_healthy = db_connected && redis_connected
    status = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? "ok" : "degraded",
      services: {
        database: db_connected ? "connected" : "unavailable",
        redis: redis_connected ? "connected" : "unavailable"
      }
    }, status: status
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError => e
    Rails.logger.warn("[HealthCheck] Database connection check failed: #{e.message}")
    false
  end

  def check_redis
    Sidekiq.redis { |conn| conn.ping } == "PONG"
  rescue StandardError => e
    Rails.logger.warn("[HealthCheck] Redis connection check failed: #{e.message}")
    false
  end
end
