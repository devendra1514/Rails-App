# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Login Rate Limiting (Rack::Attack)", type: :request do
  before do
    @original_cache = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.reset!
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @original_cache
  end

  describe "POST /admin/login throttling" do
    it "throttles IP after 5 requests in a short window", prosopite: false do
      remote_ip = "198.51.100.42"

      5.times do
        post "/admin/login",
             params: { admin: { email: "admin@example.com", password: "wrong" } },
             headers: { "X-Forwarded-For" => remote_ip }
      end

      # 6th attempt should be blocked with 429 Too Many Requests
      post "/admin/login",
           params: { admin: { email: "admin@example.com", password: "wrong" } },
           headers: { "X-Forwarded-For" => remote_ip }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
