# OpenSandbox

[中文版](README.zh-CN.md)

Ruby SDK for the [open-sandbox.ai](https://open-sandbox.ai) API — manage isolated container sandboxes for secure code execution.

> ⚠️ **This is an unofficial Ruby gem**, not affiliated with or maintained by the OpenSandbox team.
> Official project: [alibaba/OpenSandbox](https://github.com/alibaba/OpenSandbox)

[![Gem Version](https://badge.fury.io/rb/open_sandbox.svg)](https://rubygems.org/gems/open_sandbox)
[![CI](https://github.com/graysonchen/open_sandbox-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/graysonchen/open_sandbox-sdk-ruby/actions)

## What is OpenSandbox?

[OpenSandbox](https://github.com/alibaba/OpenSandbox) is a **general-purpose sandbox platform for AI applications**, open-sourced by Alibaba and listed in the [CNCF Landscape](https://landscape.cncf.io/?item=orchestration-management--scheduling-orchestration--opensandbox).

### The Problem It Solves

Modern AI applications — coding agents, browser automation, RL training, AI code execution — need to **run untrusted or model-generated code safely**. Spinning up ephemeral containers manually, wiring up lifecycle management, handling networking, streaming logs, and tearing everything down reliably is complex and error-prone.

OpenSandbox solves this by providing:

- **Isolated runtime environments** — each sandbox runs in its own container, fully isolated from the host and other workloads. Supports secure runtimes like gVisor, Kata Containers, and Firecracker microVM.
- **Unified sandbox lifecycle API** — provision, monitor, pause, resume, renew, and terminate sandboxes via a single consistent API, backed by Docker or Kubernetes.
- **In-sandbox execution** — run shell commands, execute multi-language code (Python, Node.js, etc.), manage files, expose ports, and stream logs/metrics from inside the sandbox.
- **Resource Pools** — pre-warm sandbox pools to eliminate cold-start latency for high-throughput workloads.
- **Network policy** — per-sandbox ingress/egress controls with unified gateway routing.

### Typical Use Cases

| Scenario | Description |
|---|---|
| **Coding Agents** | Run Claude Code, Gemini CLI, Codex, and other agent tools in isolated sandboxes |
| **AI Code Execution** | Safely execute model-generated code, stream outputs, iterate with reproducible environments |
| **Browser Automation** | Run Chrome / Playwright workloads with controlled runtime and networking |
| **Remote Development** | Host VS Code Web and cloud desktop environments securely |
| **RL Training** | Launch reinforcement learning tasks with managed sandbox lifecycle and resource controls |

This Ruby gem wraps the OpenSandbox HTTP API so you can use all of the above from your Ruby or Rails application.

## Installation

Add to your Gemfile:

```ruby
gem "open_sandbox", path: "../open_sandbox"   # local development
# or, once published:
gem "open_sandbox", "~> 0.1"
```

## Rails

Generate the initializer in your Rails app:

```bash
rails generate open_sandbox:install
```

This creates `config/initializers/open_sandbox.rb`:

```ruby
OpenSandbox.configure do |config|
  # config.base_url = ENV.fetch("SANDBOX_DOMAIN", "https://api.open-sandbox.ai")
  # config.api_key  = ENV.fetch("SANDBOX_API_KEY")
  # config.timeout  = 300
  # config.logger   = Rails.logger
end
```

Uncomment and adjust the options you need. By default the SDK reads `SANDBOX_DOMAIN` and `SANDBOX_API_KEY` from ENV, so the initializer can stay empty for most setups.

## Quick Start

```ruby
require "open_sandbox"

# Configure (picks up SANDBOX_DOMAIN / SANDBOX_API_KEY from ENV by default)
OpenSandbox.configure do |c|
  c.base_url = "http://localhost:8787"   # or "https://api.open-sandbox.ai"
  c.api_key  = "sk-..."                  # omit for local dev
  c.logger   = Logger.new($stdout, level: :debug)
end
```


## Runner — one-shot code execution

```ruby
# Python
result = OpenSandbox::Runner.python("print(2 ** 10)")
result.output    # => "1024\n"
result.success?  # => true
result.elapsed   # => 3.14

# Node.js
result = OpenSandbox::Runner.node("console.log('hi')")

# Shell
result = OpenSandbox::Runner.shell("echo $((6 * 7))")

# Custom image
result = OpenSandbox::Runner.call(
  image:   "ubuntu:24.04",
  command: ["bash", "-c", "ls /"],
  timeout: 60
)
```

The sandbox is always deleted after the run (even on error).
`Runner` uses `OpenSandbox.logger` — set it to `Rails.logger` in your initializer to get structured logs.

Timeout resolution order: explicit `timeout:` argument → `SANDBOX_TIMEOUT` ENV → `300` s (default).

## OpenSandbox client

```
client = OpenSandbox.client

# Create a sandbox
sandbox = client.sandboxes.create(
  image:           "python:3.11-slim",
  entrypoint:      ["python", "-c", "print(2 ** 10)"],
  timeout:         300,
  resource_limits: { "cpu" => "500m", "memory" => "256Mi" }
)
puts sandbox.id        # => "c9a03139-..."
puts sandbox.status.state  # => "Running"

# Wait until Running
client.sandboxes.wait_until(sandbox.id, target_state: OpenSandbox::SandboxState::RUNNING)

# Get endpoint for a service on port 8080
ep = client.sandboxes.endpoint(sandbox.id, port: 8080)
puts ep.url   # => "http://sb-xxx.sandbox.local:8080"

# Proxy an HTTP request directly to the sandbox
response = client.sandboxes.proxy(sandbox.id, port: 8080, method: :post,
                                  path: "/run", body: { code: "print(1)" })

# Fetch logs (Docker timestamps stripped automatically)
puts client.sandboxes.logs(sandbox.id, tail: 100)

# Lifecycle management
client.sandboxes.pause(sandbox.id)
client.sandboxes.resume(sandbox.id)
client.sandboxes.renew_expiration(sandbox.id, expires_at: Time.now + 3600)
client.sandboxes.delete(sandbox.id)
```

## Resource Pools (pre-warm for low cold-start)

```ruby
pool = client.pools.create(
  name:     "python-pool",
  template: { spec: { containers: [{ name: "main", image: "python:3.11-slim" }] } },
  capacity_spec: OpenSandbox::PoolCapacitySpec.new(
    buffer_max: 5, buffer_min: 2, pool_max: 20, pool_min: 2
  )
)

# Use the pool when creating a sandbox
client.sandboxes.create(
  image:      "python:3.11-slim",
  entrypoint: ["python", "app.py"],
  resource_limits: { "cpu" => "1", "memory" => "512Mi" },
  extensions: { "poolRef" => "python-pool" }
)
```

## Diagnostics

```ruby
puts client.sandboxes.logs(id, tail: 200, since: "10m")
puts client.sandboxes.events(id, limit: 50)
puts client.sandboxes.diagnostics(id)     # inspect + events + logs combined
```

## Configuration

| Option     | ENV var           | Default                    |
|------------|-------------------|----------------------------|
| `base_url` | `SANDBOX_DOMAIN`  | `http://localhost:8787`    |
| `api_key`  | `SANDBOX_API_KEY` | `nil` (optional for local) |
| `timeout`  | `SANDBOX_TIMEOUT` | `300` (seconds)            |
| `logger`   | —                 | `Logger.new(nil)` (silent) |

## Error Handling

```ruby
rescue OpenSandbox::NotFoundError   => e  # 404
rescue OpenSandbox::AuthenticationError   # 401
rescue OpenSandbox::ForbiddenError        # 403
rescue OpenSandbox::ConflictError         # 409
rescue OpenSandbox::ValidationError       # 422
rescue OpenSandbox::ServerError           # 5xx
rescue OpenSandbox::ConnectionError       # network / timeout
rescue OpenSandbox::Error                 # catch-all
```

## Log Utility

Strip Docker-style timestamp prefixes from raw log strings:

```ruby
raw = "2026-04-29T13:37:33.993Z 1024\n"
OpenSandbox::LogUtils.strip_timestamps(raw)
# => "1024\n"
```

## Development

```bash
bundle install
bundle exec rake test     # run all tests
```

## Other SDKs

OpenSandbox provides official SDKs for multiple languages. See the full list at [alibaba/OpenSandbox — SDKs](https://github.com/alibaba/OpenSandbox/tree/main#sdks).

## License

MIT
