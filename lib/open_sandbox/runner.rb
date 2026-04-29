# frozen_string_literal: true

module OpenSandbox
  # Runner: execute code or commands in an ephemeral sandbox and collect output.
  #
  # Opinionated wrapper around OpenSandbox::Client for short-lived,
  # fire-and-collect code execution. The sandbox is always cleaned up after use.
  #
  # == Examples
  #   result = SandboxRunnerService.run_python(<<~CODE)
  #     import math
  #     print(math.sqrt(144))
  #   CODE
  #   result.output    # => "12.0\n"
  #
  #   result = OpenSandbox::Runner.python("print(2 ** 10)")
  #   result.output    # => "1024\n"
  #   result.success?  # => true
  #   result.elapsed   # => 3.14
  #
  #   result = OpenSandbox::Runner.node("console.log('hi')")
  #   result = OpenSandbox::Runner.shell("echo $((6 * 7))")
  #
  #   result = OpenSandbox::Runner.call(
  #     image:   "ubuntu:24.04",
  #     command: ["bash", "-c", "ls /"],
  #     timeout: 60
  #   )
  #
  class Runner
    Result = Data.define(:success, :output, :sandbox_id, :elapsed) do
      alias_method :success?, :success
      def failure? = !success
    end

    DEFAULT_LIMITS  = { "cpu" => "500m", "memory" => "256Mi" }.freeze
    STARTUP_TIMEOUT = 60  # seconds to wait for sandbox to reach Running

    # ── Convenience shortcuts ─────────────────────────────────────────────

    def self.python(code, version: "3.11", timeout: nil)
      call(image: "python:#{version}-slim", command: ["python", "-c", code], timeout: timeout)
    end

    def self.node(code, version: "20", timeout: nil)
      call(image: "node:#{version}-slim", command: ["node", "-e", code], timeout: timeout)
    end

    def self.shell(command, timeout: nil)
      call(image: "ubuntu:24.04", command: ["bash", "-c", command], timeout: timeout)
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    # ── Instance ──────────────────────────────────────────────────────────

    def initialize(
      image:,
      command:,
      env:             {},
      timeout:         nil,
      resource_limits: DEFAULT_LIMITS,
      metadata:        {}
    )
      @image           = image
      @command         = command
      @env             = env
      @timeout         = timeout || OpenSandbox.configuration.timeout
      @resource_limits = resource_limits
      @metadata        = metadata
      @client          = OpenSandbox.client
    end

    def call
      started_at = Time.now
      sandbox_id = nil

      sandbox    = @client.sandboxes.create(
        image:           @image,
        entrypoint:      @command,
        env:             @env,
        timeout:         @timeout,
        resource_limits: @resource_limits,
        metadata:        @metadata
      )
      sandbox_id = sandbox.id

      @client.sandboxes.wait_until(
        sandbox_id,
        target_state: SandboxState::TERMINATED,
        timeout:      STARTUP_TIMEOUT + @timeout
      ) { |s| OpenSandbox.logger.debug("[Runner] #{sandbox_id} state=#{s.status.state}") }

      raw    = @client.sandboxes.logs(sandbox_id, tail: 1000)
      output = LogUtils.strip_timestamps(raw.to_s)

      Result.new(success: true, output: output, sandbox_id: sandbox_id, elapsed: Time.now - started_at)
    rescue OpenSandbox::Error => e
      OpenSandbox.logger.error("[Runner] #{sandbox_id}: #{e.message}")
      Result.new(success: false, output: "Error: #{e.message}", sandbox_id: sandbox_id, elapsed: Time.now - started_at)
    ensure
      begin
        @client.sandboxes.delete(sandbox_id) if sandbox_id
      rescue OpenSandbox::Error => e
        OpenSandbox.logger.warn("[Runner] cleanup failed for #{sandbox_id}: #{e.message}")
      end
    end
  end
end
