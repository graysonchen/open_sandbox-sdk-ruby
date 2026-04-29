# frozen_string_literal: true

module OpenSandbox
  # Manages sandbox lifecycle operations.
  #
  # All methods return typed value objects (Sandbox, Endpoint, etc.)
  # or raise OpenSandbox::Error subclasses on failure.
  class Sandboxes
    def initialize(http, logger: Logger.new(nil))
      @http   = http
      @logger = logger
    end

    # List all sandboxes with optional filters.
    #
    # @param page [Integer] page number (default 1)
    # @param page_size [Integer] items per page (default 20)
    # @param metadata [Hash] filter by metadata key-value pairs
    # @return [SandboxList]
    def list(page: 1, page_size: 20, metadata: {})
      query = { page: page, pageSize: page_size }
      metadata.each { |k, v| query["metadata.#{k}"] = v }
      data = @http.get("/v1/sandboxes", query: query)
      SandboxList.from_hash(data)
    end

    # Get a sandbox by ID.
    #
    # @param sandbox_id [String]
    # @return [Sandbox]
    # @raise [NotFoundError]
    def get(sandbox_id)
      data = @http.get("/v1/sandboxes/#{sandbox_id}")
      Sandbox.from_hash(data)
    end

    # Create a new sandbox.
    #
    # @param image [String] container image URI, e.g. "python:3.11"
    # @param entrypoint [Array<String>] command to run, e.g. ["python", "/app/main.py"]
    # @param resource_limits [Hash] CPU/memory limits, e.g. { cpu: "500m", memory: "512Mi" }
    # @param timeout [Integer, nil] seconds before auto-terminate (min 60); nil = no auto-terminate
    # @param env [Hash] environment variables
    # @param metadata [Hash] custom key-value labels
    # @param network_policy [Hash, nil] egress policy
    # @param volumes [Array<Hash>, nil] volume mounts
    # @param image_auth [Hash, nil] registry credentials { username:, password: }
    # @param extensions [Hash, nil] provider-specific parameters (e.g. poolRef)
    # @param platform [Hash, nil] { os: "linux", arch: "amd64" }
    # @return [Sandbox]
    def create(
      image:,
      entrypoint:,
      resource_limits: { "cpu" => "500m", "memory" => "512Mi" },
      timeout: 300,
      env: {},
      metadata: {},
      network_policy: nil,
      volumes: nil,
      image_auth: nil,
      extensions: nil,
      platform: nil
    )
      body = {
        image:          build_image_spec(image, image_auth),
        entrypoint:     entrypoint,
        resourceLimits: resource_limits.transform_keys(&:to_s),
        env:            env.transform_keys(&:to_s)
      }

      body[:timeout]       = timeout       if timeout
      body[:metadata]      = metadata.transform_keys(&:to_s) if metadata && !metadata.empty?
      body[:networkPolicy] = network_policy if network_policy
      body[:volumes]       = volumes        if volumes
      body[:extensions]    = extensions.transform_keys(&:to_s) if extensions
      body[:platform]      = { "os" => platform[:os], "arch" => platform[:arch] } if platform

      data = @http.post("/v1/sandboxes", body: body)
      Sandbox.from_hash(data)
    end

    # Delete (terminate) a sandbox.
    #
    # @param sandbox_id [String]
    # @return [nil]
    def delete(sandbox_id)
      @http.delete("/v1/sandboxes/#{sandbox_id}")
    end

    # Pause a running sandbox (preserves state).
    #
    # @param sandbox_id [String]
    # @return [nil]
    def pause(sandbox_id)
      @http.post("/v1/sandboxes/#{sandbox_id}/pause")
    end

    # Resume a paused sandbox.
    #
    # @param sandbox_id [String]
    # @return [nil]
    def resume(sandbox_id)
      @http.post("/v1/sandboxes/#{sandbox_id}/resume")
    end

    # Renew sandbox expiration time.
    #
    # @param sandbox_id [String]
    # @param expires_at [Time] new expiration time (must be in the future)
    # @return [Time] new expiration time
    def renew_expiration(sandbox_id, expires_at:)
      body = { "expiresAt" => expires_at.utc.iso8601 }
      data = @http.post("/v1/sandboxes/#{sandbox_id}/renew-expiration", body: body)
      Time.parse(data["expiresAt"])
    end

    # Get public endpoint URL for a service port inside the sandbox.
    #
    # @param sandbox_id [String]
    # @param port [Integer] port number where the service listens
    # @param use_server_proxy [Boolean] return server-proxied URL
    # @return [Endpoint]
    def endpoint(sandbox_id, port:, use_server_proxy: false)
      data = @http.get(
        "/v1/sandboxes/#{sandbox_id}/endpoints/#{port}",
        query: { useServerProxy: use_server_proxy }
      )
      Endpoint.from_hash(data)
    end

    # Proxy an HTTP request to a service running inside the sandbox.
    #
    # @param sandbox_id [String]
    # @param port [Integer]
    # @param method [Symbol] :get, :post, :put, :patch, :delete
    # @param path [String] path within the proxied service (default "/")
    # @param body [Hash, nil] request body
    # @param headers [Hash] additional headers
    # @return [HTTParty::Response] raw response
    def proxy(sandbox_id, port:, method: :get, path: "/", body: nil, headers: {})
      proxy_path = path == "/" || path.empty? \
        ? "/v1/sandboxes/#{sandbox_id}/proxy/#{port}" \
        : "/v1/sandboxes/#{sandbox_id}/proxy/#{port}/#{path.delete_prefix('/')}"

      @http.proxy(method, proxy_path, body: body, headers: headers)
    end

    # ── Diagnostics ─────────────────────────────────────────────────────────

    # Get container logs for a sandbox.
    #
    # @param sandbox_id [String]
    # @param tail [Integer] number of trailing lines
    # @param since [String, nil] duration string, e.g. "10m", "1h"
    # @return [String]
    def logs(sandbox_id, tail: 100, since: nil)
      query = { tail: tail }
      query[:since] = since if since
      @http.get("/v1/sandboxes/#{sandbox_id}/diagnostics/logs", query: query)
    end

    # Get detailed container inspection info.
    #
    # @param sandbox_id [String]
    # @return [String]
    def inspect_container(sandbox_id)
      @http.get("/v1/sandboxes/#{sandbox_id}/diagnostics/inspect")
    end

    # Get events for a sandbox.
    #
    # @param sandbox_id [String]
    # @param limit [Integer]
    # @return [String]
    def events(sandbox_id, limit: 50)
      @http.get("/v1/sandboxes/#{sandbox_id}/diagnostics/events", query: { limit: limit })
    end

    # Get combined diagnostics summary (inspect + events + logs).
    #
    # @param sandbox_id [String]
    # @param tail [Integer]
    # @param event_limit [Integer]
    # @return [String]
    def diagnostics(sandbox_id, tail: 50, event_limit: 20)
      @http.get(
        "/v1/sandboxes/#{sandbox_id}/diagnostics/summary",
        query: { tail: tail, eventLimit: event_limit }
      )
    end

    # ── Polling helpers ──────────────────────────────────────────────────────

    # Wait until sandbox reaches a target state (or fails/terminates).
    #
    # @param sandbox_id [String]
    # @param target_state [String] e.g. SandboxState::RUNNING
    # @param timeout [Integer] max seconds to wait
    # @param interval [Numeric] polling interval in seconds
    # @yield [Sandbox] called after each poll (optional)
    # @return [Sandbox] when target state reached
    # @raise [Error] if sandbox fails or timeout exceeded
    def wait_until(sandbox_id, target_state:, timeout: 120, interval: 2)
      deadline = Time.now + timeout
      loop do
        sandbox = get(sandbox_id)
        yield sandbox if block_given?

        return sandbox if sandbox.status.state == target_state

        if sandbox.status.failed? || sandbox.status.terminated?
          raise Error, "Sandbox #{sandbox_id} entered #{sandbox.status.state} state: #{sandbox.status.message}"
        end

        raise Error, "Timed out waiting for sandbox #{sandbox_id} to reach #{target_state}" if Time.now >= deadline

        sleep interval
      end
    end

    private

    def build_image_spec(image, auth)
      spec = { "uri" => image }
      if auth
        spec["auth"] = { "username" => auth[:username].to_s, "password" => auth[:password].to_s }
      end
      spec
    end
  end
end
