# frozen_string_literal: true

# Rack::Attack configuration for request throttling and abuse prevention.
# Documentation: https://github.com/rack/rack-attack

class Rack::Attack
  # Use Rails.cache for counter storage (Redis in production, MemoryStore in development).
  Rack::Attack.cache.store = Rails.cache

  ### Safelists ###

  # Always allow health check requests without throttling
  safelist("allow-health-check") do |req|
    req.path == "/up"
  end

  # Allow all requests from localhost in development and test environments
  safelist("allow-localhost") do |req|
    (req.ip == "127.0.0.1" || req.ip == "::1") if Rails.env.development? || Rails.env.test?
  end

  ### Blocklists ###

  # Block obvious malicious vulnerability probes and scanners
  blocklist("block-vulnerability-scanners") do |req|
    req.path.match?(%r{\.(php|asp|aspx|jsp)$|\.env|wp-admin|wp-login|xmlrpc|phpmyadmin}i)
  end

  ### Throttles ###

  # General volumetric IP throttle: 1000 requests per minute per IP
  throttle("req/ip", limit: 1000, period: 1.minute) do |req|
    req.ip
  end

  # --- Future Endpoint-Specific Throttle Examples ---
  #
  # Example: Throttle POST requests to login endpoints by IP (e.g., 20 attempts per minute)
  # throttle("logins/ip", limit: 20, period: 1.minute) do |req|
  #   req.ip if req.path == "/users/sign_in" && req.post?
  # end
  #
  # Example: Throttle POST requests to login endpoints by email (e.g., 5 attempts per 20 seconds)
  # throttle("logins/email", limit: 5, period: 20.seconds) do |req|
  #   if req.path == "/users/sign_in" && req.post?
  #     req.params.dig("user", "email").to_s.downcase.strip.presence
  #   end
  # end

  ### Custom Responses ###

  # Return a structured 429 response when requests are throttled
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]

    accept_json = req.get_header("HTTP_ACCEPT")&.include?("application/json")

    if req.path.start_with?("/api/") || accept_json || req.media_type == "application/json"
      [
        429,
        {
          "Content-Type" => "application/json",
          "Retry-After" => retry_after.to_s
        },
        [ { error: "Too Many Requests", message: "Rate limit exceeded. Please try again later." }.to_json ]
      ]
    else
      [
        429,
        {
          "Content-Type" => "text/plain",
          "Retry-After" => retry_after.to_s
        },
        [ "Rate limit exceeded. Please try again later.\n" ]
      ]
    end
  end

  ### Logging & Notifications ###

  ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, _start, _finish, _id, payload|
    req = payload[:request]
    rule = payload[:matched]
    discriminator = payload[:match_discriminator]

    Rails.logger.warn(
      "[Rack::Attack] #{name} rule=#{rule} ip=#{req.ip} path=#{req.path} match=#{discriminator}"
    )
  end
end
