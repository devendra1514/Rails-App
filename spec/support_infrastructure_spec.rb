# frozen_string_literal: true

require "rails_helper"

RSpec.describe "RSpec support infrastructure" do
  describe "FactoryBot integration" do
    it "responds to FactoryBot syntax methods" do
      expect(respond_to?(:build)).to be true
      expect(respond_to?(:create)).to be true
      expect(respond_to?(:attributes_for)).to be true
    end
  end

  describe "Faker integration" do
    it "generates fake data" do
      expect(Faker::Internet.email).to include("@")
      expect(Faker::Name.name).to be_present
    end
  end

  describe "Shoulda Matchers integration", type: :model do
    it "integrates shoulda matchers with ActiveModel" do
      dummy_class = Class.new do
        include ActiveModel::Model
        attr_accessor :title

        validates :title, presence: true

        def self.model_name
          ActiveModel::Name.new(self, nil, "Dummy")
        end
      end

      expect(dummy_class.new).to validate_presence_of(:title)
    end
  end

  describe "Sidekiq support" do
    it "runs in fake testing mode and clears queues" do
      expect(Sidekiq::Testing.fake?).to be true
      expect(Sidekiq::Queues.jobs_by_queue.values.flatten).to be_empty
    end
  end
end
