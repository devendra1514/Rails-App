# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppConfig do
  describe ".dig" do
    it "returns the configured app_name" do
      expect(described_class.dig(:app_name)).to eq("App")
    end

    it "returns nested values for active environment" do
      expect(described_class.dig(:database, :name)).to eq("app_test")
      expect(described_class.dig(:database, :host)).to eq("localhost")
      expect(described_class.dig(:redis, :url)).to eq("redis://localhost:6379/0")
    end

    it "returns nil for non-existent keys" do
      expect(described_class.dig(:non_existent_key)).to be_nil
      expect(described_class.dig(:database, :non_existent_sub_key)).to be_nil
    end
  end

  describe ".dig!" do
    it "returns the configured value when present" do
      expect(described_class.dig!(:app_name)).to eq("App")
      expect(described_class.dig!(:database, :name)).to eq("app_test")
    end

    it "raises KeyError for missing keys" do
      expect { described_class.dig!(:non_existent_key) }.to raise_error(KeyError, /non_existent_key/)
    end
  end

  describe ".for" do
    it "loads development environment settings" do
      dev_config = described_class.for(:development)
      expect(dev_config.dig(:database, :name)).to eq("app_development")
      expect(dev_config.dig(:database, :host)).to eq("localhost")
      expect(dev_config.dig(:app_name)).to eq("App")
    end

    it "loads test environment settings" do
      test_config = described_class.for(:test)
      expect(test_config.dig(:database, :name)).to eq("app_test")
      expect(test_config.dig(:database, :host)).to eq("localhost")
      expect(test_config.dig(:app_name)).to eq("App")
    end

    it "respects ENV['DATABASE_HOST'] override when set" do
      begin
        original_host = ENV["DATABASE_HOST"]
        ENV["DATABASE_HOST"] = "postgres-custom-host"
        described_class.reload!

        expect(described_class.for(:development).dig(:database, :host)).to eq("postgres-custom-host")
        expect(described_class.for(:test).dig(:database, :host)).to eq("postgres-custom-host")
      ensure
        ENV["DATABASE_HOST"] = original_host
        described_class.reload!
      end
    end
  end

  describe ".env" do
    it "returns the current Rails environment" do
      expect(described_class.env).to eq("test")
    end
  end
end
