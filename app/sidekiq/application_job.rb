# frozen_string_literal: true

# Base Sidekiq job class for the application.
# All inheriting jobs receive Sidekiq::Job capabilities and standard default options.
class ApplicationJob
  include Sidekiq::Job

  # Default Sidekiq options across all jobs:
  # - Default queue: :default (options: :critical, :default, :mailers, :low)
  # - Retry count: 3 (overridable in subclasses)
  sidekiq_options queue: :default, retry: 3
end
