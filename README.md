# OpenSandbox

Ruby SDK for the [open-sandbox.ai](https://open-sandbox.ai) API — manage isolated container sandboxes for secure code execution.

[![Gem Version](https://badge.fury.io/rb/open_sandbox.svg)](https://rubygems.org/gems/open_sandbox)
[![CI](https://github.com/graysonchen/open_sandbox-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/graysonchen/open_sandbox-sdk-ruby/actions)

## Installation

Add to your Gemfile:

```ruby
gem "open_sandbox", path: "../open_sandbox"   # local development
# or, once published:
gem "open_sandbox", "~> 0.1"
```

## Quick Start

```ruby
require "open_sandbox"

# Configure (picks up SANDBOX_DOMAIN / SANDBOX_API_KEY from ENV by default)
OpenSandbox.configure do |c|
  c.base_url = "http://localhost:8787"   # or "https://api.open-sandbox.ai"
  c.api_key  = "sk-..."                  # omit for local dev
  c.logger   = Logger.new($stdout, level: :debug)
end

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
| `timeout`  | `SANDBOX_TIMEOUT` | `30` (seconds)             |
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

## License

MIT
