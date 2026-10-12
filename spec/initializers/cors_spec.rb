# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS configuration", type: :request do
  describe "AppConfig CORS origin resolution" do
    it "configures wildcard origins for test environment" do
      expect(AppConfig.for(:test).dig(:cors, :allowed_origins)).to eq("*")
    end

    it "configures wildcard origins for development environment" do
      expect(AppConfig.for(:development).dig(:cors, :allowed_origins)).to eq("*")
    end

    it "configures explicit domain array for production environment" do
      expect(AppConfig.for(:production).dig(:cors, :allowed_origins)).to eq([ "https://example.com" ])
    end
  end

  describe "HTTP CORS headers" do
    it "allows preflight OPTIONS requests with wildcard origin in test environment" do
      options "/up", headers: {
        "Origin" => "https://myclient.example.com",
        "Access-Control-Request-Method" => "GET",
        "Access-Control-Request-Headers" => "Authorization"
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Expose-Headers"]).to include("Authorization")
    end
  end
end
