# frozen_string_literal: true

RSpec.configure do |config|
  # Disable Rack::Attack by default in test suite so normal specs are unaffected
  config.before(:each) do
    Rack::Attack.enabled = false
  end
end
