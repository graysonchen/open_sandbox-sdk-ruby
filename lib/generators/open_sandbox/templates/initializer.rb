# frozen_string_literal: true

require "open_sandbox"

# Configuration reference:
#   base_url — API endpoint (default: ENV["SANDBOX_DOMAIN"] || "http://localhost:8787")
#   api_key  — Authentication key (default: ENV["SANDBOX_API_KEY"])
#   timeout  — HTTP request timeout in seconds (default: 30)
#   logger   — Ruby Logger instance (default: silent)
#
OpenSandbox.configure do |config|
  # Set via Rails credentials: Rails.application.credentials.sandbox_domain
  config.base_url = ENV.fetch("SANDBOX_DOMAIN", "http://localhost:8080")

  # API Key: optional for local dev, required for production
  # Set via Rails credentials: Rails.application.credentials.sandbox_api_key
  config.api_key  = ENV.fetch("SANDBOX_API_KEY", nil)

  # HTTP timeout in seconds
  config.timeout  = ENV.fetch("SANDBOX_TIMEOUT", 300).to_i

  # config.logger   = Logger.new($stdout, level: :debug)
end
