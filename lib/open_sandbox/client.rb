# frozen_string_literal: true

require "logger"
require_relative "errors"
require_relative "models"
require_relative "http_client"
require_relative "sandboxes"
require_relative "pools"

# OpenSandbox Ruby SDK
#
# Wraps the open-sandbox.ai REST API for managing isolated container sandboxes.
#
# == Quick Start
#
#   client = OpenSandbox::Client.new
#
#   sandbox = client.sandboxes.create(
#     image:      "python:3.11-slim",
#     entrypoint: ["python", "-c", "print('hello')"],
#     timeout:    300
#   )
#
#   client.sandboxes.wait_until(sandbox.id, target_state: OpenSandbox::SandboxState::RUNNING)
#   endpoint = client.sandboxes.endpoint(sandbox.id, port: 8080)
#   client.sandboxes.delete(sandbox.id)
#
# == Configuration
#
#   OpenSandbox.configure do |c|
#     c.base_url = "https://api.open-sandbox.ai"
#     c.api_key  = "sk-..."
#     c.timeout  = 300
#     c.logger   = Logger.new($stdout, level: :info)
#   end
#
module OpenSandbox
  # Global configuration object
  class Configuration
    attr_accessor :base_url, :api_key, :timeout, :logger

    def initialize
      @base_url = ENV.fetch("SANDBOX_DOMAIN", "http://localhost:8787")
      @api_key  = ENV.fetch("SANDBOX_API_KEY", nil)
      @timeout  = ENV.fetch("SANDBOX_TIMEOUT", 300).to_i
      @logger   = Logger.new(nil) # silent by default
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
      reset_client!
    end

    # Shortcut: OpenSandbox.client (singleton, reset after configure)
    def client
      @client ||= Client.new
    end

    def reset_client!
      @client = nil
    end

    # Convenience delegators
    def logger = configuration.logger
  end

  # Main entry point for the OpenSandbox SDK.
  class Client
    # @param base_url [String, nil] override global config
    # @param api_key  [String, nil] override global config
    # @param timeout  [Integer, nil] override global config
    # @param logger   [Logger, nil] override global config
    def initialize(base_url: nil, api_key: nil, timeout: nil, logger: nil)
      cfg       = OpenSandbox.configuration
      @base_url = base_url || cfg.base_url
      @api_key  = api_key  || cfg.api_key
      @timeout  = timeout  || cfg.timeout
      @logger   = logger   || cfg.logger
    end

    # @return [Sandboxes]
    def sandboxes
      @sandboxes ||= Sandboxes.new(http, logger: @logger)
    end

    # @return [Pools]
    def pools
      @pools ||= Pools.new(http)
    end

    # Health check — returns true if the server responds successfully.
    # @return [Boolean]
    def healthy?
      http.get("/health")
      true
    rescue Error
      false
    end

    private

    def http
      @http ||= HttpClient.new(base_url: @base_url, api_key: @api_key, timeout: @timeout)
    end
  end
end
