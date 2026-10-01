# frozen_string_literal: true

require_relative "../../lib/app_config"

# Preload and validate configuration on application boot
AppConfig.dig!(:app_name)
