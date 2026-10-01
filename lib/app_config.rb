# frozen_string_literal: true

require "yaml"
require "erb"
require "pathname"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/hash/keys"

class AppConfig
  class << self
    # Access settings for the current active environment
    def dig(*keys)
      current.dig(*keys.map(&:to_sym))
    end

    # Strict access for current environment (raises KeyError if nil)
    def dig!(*keys)
      value = dig(*keys)
      if value.nil?
        raise KeyError, "Missing config key in AppConfig: #{keys.map(&:inspect).join(' -> ')}"
      end
      value
    end

    # Explicit access for a specific environment (e.g. AppConfig.for(:production).dig(...))
    def for(environment)
      load_environment(environment.to_s)
    end

    # Reload cached settings
    def reload!
      @environments = {}
      @current = nil
      current
    end

    # Resolves the active environment strictly; raises error if cannot be determined
    def env
      if defined?(Rails.env) && Rails.env.presence
        Rails.env.to_s
      elsif ENV["RAILS_ENV"].present?
        ENV["RAILS_ENV"]
      elsif ENV["RACK_ENV"].present?
        ENV["RACK_ENV"]
      else
        raise ArgumentError, "Cannot determine environment: Rails.env or RAILS_ENV must be set."
      end
    end

    private

    def current
      @current ||= self.for(env)
    end

    def environments
      @environments ||= {}
    end

    def load_environment(environment_name)
      environments[environment_name] ||= begin
        dir = settings_directory

        base_path = dir.join("settings.yml")
        unless base_path.exist?
          raise Errno::ENOENT, "Base settings file missing: #{base_path}"
        end

        env_path = dir.join("settings-#{environment_name}.yml")
        unless env_path.exist?
          raise Errno::ENOENT, "Settings file missing for environment '#{environment_name}': #{env_path}"
        end

        base = load_yaml(base_path)
        env_override = load_yaml(env_path)

        base.deep_merge(env_override)
      end
    end

    def settings_directory
      if defined?(Rails.root) && Rails.root
        Rails.root.join("config/settings")
      else
        Pathname.new(File.expand_path("../config/settings", __dir__))
      end
    end

    def load_yaml(path)
      rendered = ERB.new(File.read(path)).result
      (YAML.safe_load(rendered, permitted_classes: [Symbol, Date, Time], aliases: true) || {}).deep_symbolize_keys
    end
  end
end
