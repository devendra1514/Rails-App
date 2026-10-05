# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppConfig do
  describe ".dig!" do
    it "returns the configured app_name" do
      expect(described_class.dig!(:app_name)).to eq("App")
    end

    it "raises KeyError for missing keys" do
      expect { described_class.dig!(:non_existent_key) }.to raise_error(KeyError)
    end
  end
end
