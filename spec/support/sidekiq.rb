# frozen_string_literal: true

# Enable modern Sidekiq testing mode (jobs enqueued in-memory without Redis)
Sidekiq.testing!(:fake)

RSpec.configure do |config|
  config.before(:each) do
    Sidekiq::Job.clear_all
  end
end
