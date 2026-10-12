# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = memory_store
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.throttles.delete("test_throttle")
    Rack::Attack.reset!
    Rack::Attack.enabled = false
  end

  describe "safelist" do
    it "allows /up health check without throttling" do
      get "/up", headers: { "REMOTE_ADDR" => "198.51.100.1" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "blocklist" do
    it "blocks requests seeking .env with 403 Forbidden" do
      get "/.env", headers: { "REMOTE_ADDR" => "198.51.100.1" }
      expect(response).to have_http_status(:forbidden)
    end

    it "blocks requests seeking php/wordpress scanner paths with 403 Forbidden" do
      get "/wp-login.php", headers: { "REMOTE_ADDR" => "198.51.100.1" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "throttling" do
    before do
      Rack::Attack.throttle("test_throttle", limit: 2, period: 1.minute) do |req|
        req.ip if req.path == "/test_throttle"
      end
    end

    it "throttles when exceeding the limit and returns 429 with Retry-After" do
      # First 2 requests within limit
      2.times do
        get "/test_throttle", headers: { "REMOTE_ADDR" => "198.51.100.50" }
        expect(response).to have_http_status(:not_found)
      end

      # 3rd request exceeds limit
      get "/test_throttle", headers: { "REMOTE_ADDR" => "198.51.100.50" }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
      expect(response.body).to include("Rate limit exceeded")
    end

    it "returns JSON error for API requests when throttled" do
      3.times do
        get "/test_throttle", headers: { "REMOTE_ADDR" => "198.51.100.60", "Accept" => "application/json" }
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(response.content_type).to include("application/json")
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Too Many Requests")
      expect(json["message"]).to include("Rate limit exceeded")
    end
  end
end
