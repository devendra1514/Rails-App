# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  it "formats the default from address with app_name and sender_email" do
    expect(described_class.default[:from].call).to eq("App <support@example.com>")
  end
end
