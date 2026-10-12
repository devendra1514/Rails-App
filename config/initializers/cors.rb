# frozen_string_literal: true

# Avoid CORS issues when API is called from frontend clients.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.
# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*Array(AppConfig.dig(:cors, :allowed_origins)))

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: %i[get post put patch delete options head]
  end
end
