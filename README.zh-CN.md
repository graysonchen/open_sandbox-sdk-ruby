# OpenSandbox

[English](README.md)

[open-sandbox.ai](https://open-sandbox.ai) API 的 Ruby SDK — 管理隔离容器沙箱，实现安全的代码执行。

> ⚠️ **这是一个非官方 Ruby gem**，与 OpenSandbox 团队无关联，亦非由其维护。
> 官方项目：[alibaba/OpenSandbox](https://github.com/alibaba/OpenSandbox)

[![Gem Version](https://badge.fury.io/rb/open_sandbox.svg)](https://rubygems.org/gems/open_sandbox)
[![CI](https://github.com/graysonchen/open_sandbox-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/graysonchen/open_sandbox-sdk-ruby/actions)

## 什么是 OpenSandbox？

[OpenSandbox](https://github.com/alibaba/OpenSandbox) 是阿里巴巴开源的 **AI 应用通用沙箱平台**，已收录于 [CNCF Landscape](https://landscape.cncf.io/?item=orchestration-management--scheduling-orchestration--opensandbox)。

### 解决的问题

现代 AI 应用 — 编码 Agent、浏览器自动化、强化学习训练、AI 代码执行 — 需要**安全地运行不受信任或模型生成的代码**。手动启动临时容器、连接生命周期管理、处理网络、流式传输日志、并可靠地清理资源，既复杂又容易出错。

OpenSandbox 通过以下方式解决这些问题：

- **隔离运行时环境** — 每个沙箱运行在独立容器中，与宿主机和其他工作负载完全隔离。支持 gVisor、Kata Containers、Firecracker microVM 等安全运行时。
- **统一沙箱生命周期 API** — 通过单一一致的 API 完成沙箱的创建、监控、暂停、恢复、续期和销毁，底层支持 Docker 或 Kubernetes。
- **沙箱内执行** — 在沙箱内运行 Shell 命令、执行多语言代码（Python、Node.js 等）、管理文件、暴露端口，并流式传输日志和指标。
- **资源池** — 预热沙箱池，消除高吞吐量工作负载的冷启动延迟。
- **网络策略** — 每个沙箱独立的入站/出站控制，配合统一网关路由。

### 典型使用场景

| 场景 | 描述 |
|---|---|
| **编码 Agent** | 在隔离沙箱中运行 Claude Code、Gemini CLI、Codex 等 Agent 工具 |
| **AI 代码执行** | 安全执行模型生成的代码，流式输出结果，在可复现的环境中迭代 |
| **浏览器自动化** | 以受控的运行时和网络环境运行 Chrome / Playwright 工作负载 |
| **远程开发** | 安全托管 VS Code Web 和云桌面环境 |
| **强化学习训练** | 启动 RL 任务，配合托管的沙箱生命周期和资源控制 |

该 Ruby gem 封装了 OpenSandbox HTTP API，让你可以在 Ruby 或 Rails 应用中使用上述所有功能。

## 安装

在 Gemfile 中添加：

```ruby
gem "open_sandbox", path: "../open_sandbox"   # 本地开发
# 或发布后：
gem "open_sandbox", "~> 0.1"
```

## Rails 集成

在 Rails 应用中生成初始化文件：

```bash
rails generate open_sandbox:install
```

这会创建 `config/initializers/open_sandbox.rb`：

```ruby
OpenSandbox.configure do |config|
  # config.base_url = ENV.fetch("SANDBOX_DOMAIN", "https://api.open-sandbox.ai")
  # config.api_key  = ENV.fetch("SANDBOX_API_KEY")
  # config.timeout  = 300
  # config.logger   = Rails.logger
end
```

按需取消注释并调整选项。默认情况下，SDK 从环境变量中读取 `SANDBOX_DOMAIN` 和 `SANDBOX_API_KEY`，大多数情况下初始化文件可以保持为空。

## 快速开始

```ruby
require "open_sandbox"

# 配置（默认从 ENV 读取 SANDBOX_DOMAIN / SANDBOX_API_KEY）
OpenSandbox.configure do |c|
  c.base_url = "http://localhost:8787"   # 或 "https://api.open-sandbox.ai"
  c.api_key  = "sk-..."                  # 本地开发可省略
  c.logger   = Logger.new($stdout, level: :debug)
end
```

## Runner — 一次性代码执行

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

# 自定义镜像
result = OpenSandbox::Runner.call(
  image:   "ubuntu:24.04",
  command: ["bash", "-c", "ls /"],
  timeout: 60
)
```

运行完成后（包括出错时）沙箱会自动删除。
`Runner` 使用 `OpenSandbox.logger` — 在初始化文件中设置为 `Rails.logger` 可获得结构化日志。

超时时间优先级：显式 `timeout:` 参数 → `SANDBOX_TIMEOUT` 环境变量 → 默认 `300` 秒。

## OpenSandbox 客户端

```ruby
client = OpenSandbox.client

# 创建沙箱
sandbox = client.sandboxes.create(
  image:           "python:3.11-slim",
  entrypoint:      ["python", "-c", "print(2 ** 10)"],
  timeout:         300,
  resource_limits: { "cpu" => "500m", "memory" => "256Mi" }
)
puts sandbox.id        # => "c9a03139-..."
puts sandbox.status.state  # => "Running"

# 等待沙箱进入 Running 状态
client.sandboxes.wait_until(sandbox.id, target_state: OpenSandbox::SandboxState::RUNNING)

# 获取沙箱内 8080 端口的访问地址
ep = client.sandboxes.endpoint(sandbox.id, port: 8080)
puts ep.url   # => "http://sb-xxx.sandbox.local:8080"

# 将 HTTP 请求直接代理到沙箱
response = client.sandboxes.proxy(sandbox.id, port: 8080, method: :post,
                                  path: "/run", body: { code: "print(1)" })

# 获取日志（自动去除 Docker 时间戳前缀）
puts client.sandboxes.logs(sandbox.id, tail: 100)

# 生命周期管理
client.sandboxes.pause(sandbox.id)
client.sandboxes.resume(sandbox.id)
client.sandboxes.renew_expiration(sandbox.id, expires_at: Time.now + 3600)
client.sandboxes.delete(sandbox.id)
```

## 资源池（预热以降低冷启动延迟）

```ruby
pool = client.pools.create(
  name:     "python-pool",
  template: { spec: { containers: [{ name: "main", image: "python:3.11-slim" }] } },
  capacity_spec: OpenSandbox::PoolCapacitySpec.new(
    buffer_max: 5, buffer_min: 2, pool_max: 20, pool_min: 2
  )
)

# 创建沙箱时使用资源池
client.sandboxes.create(
  image:      "python:3.11-slim",
  entrypoint: ["python", "app.py"],
  resource_limits: { "cpu" => "1", "memory" => "512Mi" },
  extensions: { "poolRef" => "python-pool" }
)
```

## 诊断

```ruby
puts client.sandboxes.logs(id, tail: 200, since: "10m")
puts client.sandboxes.events(id, limit: 50)
puts client.sandboxes.diagnostics(id)     # inspect + events + logs 三合一
```

## 配置项

| 选项       | 环境变量           | 默认值                     |
|------------|-------------------|----------------------------|
| `base_url` | `SANDBOX_DOMAIN`  | `http://localhost:8787`    |
| `api_key`  | `SANDBOX_API_KEY` | `nil`（本地可省略）         |
| `timeout`  | `SANDBOX_TIMEOUT` | `300`（秒）                |
| `logger`   | —                 | `Logger.new(nil)`（静默）  |

## 错误处理

```ruby
rescue OpenSandbox::NotFoundError   => e  # 404
rescue OpenSandbox::AuthenticationError   # 401
rescue OpenSandbox::ForbiddenError        # 403
rescue OpenSandbox::ConflictError         # 409
rescue OpenSandbox::ValidationError       # 422
rescue OpenSandbox::ServerError           # 5xx
rescue OpenSandbox::ConnectionError       # 网络 / 超时
rescue OpenSandbox::Error                 # 兜底捕获
```

## 日志工具

从原始日志字符串中去除 Docker 风格的时间戳前缀：

```ruby
raw = "2026-04-29T13:37:33.993Z 1024\n"
OpenSandbox::LogUtils.strip_timestamps(raw)
# => "1024\n"
```

## 开发

```bash
bundle install
bundle exec rake test     # 运行所有测试
```

## 其他 SDK

OpenSandbox 提供多种语言的官方 SDK，完整列表请参见 [alibaba/OpenSandbox — SDKs](https://github.com/alibaba/OpenSandbox/tree/main#sdks)。

## 许可证

MIT
