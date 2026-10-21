# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiController, type: :controller do
  it "includes Pagy::Method" do
    expect(described_class.ancestors).to include(Pagy::Method)
  end

  it "defines the pagy pagination method" do
    expect(described_class.method_defined?(:pagy)).to be(true)
  end
end
