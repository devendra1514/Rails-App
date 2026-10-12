# frozen_string_literal: true

# Auto-detect N+1 queries in tests via Prosopite
if defined?(Prosopite)
  RSpec.configure do |config|
    config.before(:each) do |example|
      Prosopite.scan unless example.metadata[:prosopite] == false
    end

    config.after(:each) do |example|
      Prosopite.finish unless example.metadata[:prosopite] == false
    end
  end
end
