# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Checks", type: :request do
  describe "GET /up" do
    it "returns 200 OK from Rails health check" do
      get "/up"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /up/deep" do
    context "when all services are healthy" do
      it "returns 200 OK with connected status" do
        get "/up/deep"
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["services"]["database"]).to eq("connected")
        expect(json["services"]["redis"]).to eq("connected")
      end
    end

    context "when database is disconnected" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::ConnectionNotEstablished, "DB connection failed")
      end

      it "returns 503 Service Unavailable with database marked unavailable" do
        get "/up/deep"
        expect(response).to have_http_status(:service_unavailable)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("degraded")
        expect(json["services"]["database"]).to eq("unavailable")
      end
    end

    context "when redis is disconnected" do
      before do
        allow(Sidekiq).to receive(:redis).and_raise(Redis::CannotConnectError, "Redis connection failed")
      end

      it "returns 503 Service Unavailable with redis marked unavailable" do
        get "/up/deep"
        expect(response).to have_http_status(:service_unavailable)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("degraded")
        expect(json["services"]["redis"]).to eq("unavailable")
      end
    end
  end
end
