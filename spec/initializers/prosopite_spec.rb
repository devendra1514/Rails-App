# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Prosopite configuration" do
  it "is enabled and configured to raise errors in test environment" do
    expect(Prosopite.enabled?).to be true
    expect(Prosopite.raise?).to be true
  end

  it "detects N+1 queries when duplicate queries execute", prosopite: false do
    ActiveRecord::Base.connection.create_table(:prosopite_test_items, temporary: true) do |t|
      t.string :name
    end

    test_model = Class.new(ApplicationRecord) do
      self.table_name = "prosopite_test_items"
    end

    3.times { |i| test_model.create!(name: "item_#{i}") }

    expect do
      Prosopite.scan do
        3.times do |i|
          test_model.where(id: i + 1).first
        end
      end
    end.to raise_error(Prosopite::NPlusOneQueriesError)
  ensure
    ActiveRecord::Base.connection.drop_table(:prosopite_test_items, if_exists: true)
  end

  it "bypasses scanning when prosopite: false metadata is specified", prosopite: false do
    expect(Prosopite.scan?).to be false
  end
end
