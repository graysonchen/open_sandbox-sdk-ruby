# frozen_string_literal: true

require "test_helper"

# Tests for Sandboxes and Pools using WebMock to stub HTTP calls.
class SandboxesTest < Minitest::Test
  BASE = "http://localhost:8787"

  def setup
    @client = OpenSandbox::Client.new(base_url: BASE)
  end

  # ── list ──────────────────────────────────────────────────────────────────

  def test_list_returns_sandbox_list
    stub_get "/v1/sandboxes", list_response([ sandbox_payload ]),
             query: { "page" => "1", "pageSize" => "20" }
    result = @client.sandboxes.list
    assert_instance_of OpenSandbox::SandboxList, result
    assert_equal 1, result.items.length
    assert_equal "sb-abc", result.items.first.id
  end

  def test_list_passes_pagination_params
    stub_get "/v1/sandboxes", list_response([]),
             query: { "page" => "2", "pageSize" => "5" }
    result = @client.sandboxes.list(page: 2, page_size: 5)
    assert_equal 0, result.items.length
  end

  # ── get ───────────────────────────────────────────────────────────────────

  def test_get_returns_sandbox
    stub_get "/v1/sandboxes/sb-abc", sandbox_payload
    sb = @client.sandboxes.get("sb-abc")
    assert_equal "sb-abc",            sb.id
    assert_equal "python:3.11-slim",  sb.image_uri
    assert sb.status.running?
  end

  def test_get_raises_not_found
    stub_request(:get, "#{BASE}/v1/sandboxes/missing")
      .to_return(status: 404, body: '{"code":"NOT_FOUND","message":"not found"}', headers: json_header)
    assert_raises(OpenSandbox::NotFoundError) { @client.sandboxes.get("missing") }
  end

  # ── create ────────────────────────────────────────────────────────────────

  def test_create_returns_sandbox
    stub_request(:post, "#{BASE}/v1/sandboxes")
      .to_return(status: 201, body: sandbox_payload.to_json, headers: json_header)
    sb = @client.sandboxes.create(
      image:           "python:3.11-slim",
      entrypoint:      ["python", "-c", "print(1)"],
      resource_limits: { "cpu" => "500m", "memory" => "256Mi" }
    )
    assert_equal "sb-abc", sb.id
  end

  def test_create_raises_validation_error
    stub_request(:post, "#{BASE}/v1/sandboxes")
      .to_return(status: 422, body: '{"code":"VALIDATION","message":"bad input"}', headers: json_header)
    assert_raises(OpenSandbox::ValidationError) do
      @client.sandboxes.create(image: "x", entrypoint: ["cmd"], resource_limits: {})
    end
  end

  # ── delete ────────────────────────────────────────────────────────────────

  def test_delete_returns_nil
    stub_request(:delete, "#{BASE}/v1/sandboxes/sb-abc")
      .to_return(status: 204, body: "")
    assert_nil @client.sandboxes.delete("sb-abc")
  end

  # ── pause / resume ────────────────────────────────────────────────────────

  def test_pause_accepts_202
    stub_request(:post, "#{BASE}/v1/sandboxes/sb-abc/pause")
      .to_return(status: 202, body: "{}", headers: json_header)
    @client.sandboxes.pause("sb-abc") # should not raise
  end

  def test_resume_accepts_202
    stub_request(:post, "#{BASE}/v1/sandboxes/sb-abc/resume")
      .to_return(status: 202, body: "{}", headers: json_header)
    @client.sandboxes.resume("sb-abc")
  end

  # ── renew_expiration ──────────────────────────────────────────────────────

  def test_renew_expiration_returns_time
    new_time = "2025-12-31T23:59:59Z"
    stub_request(:post, "#{BASE}/v1/sandboxes/sb-abc/renew-expiration")
      .to_return(status: 200, body: { "expiresAt" => new_time }.to_json, headers: json_header)
    result = @client.sandboxes.renew_expiration("sb-abc", expires_at: Time.now + 3600)
    assert_instance_of Time, result
  end

  # ── endpoint ──────────────────────────────────────────────────────────────

  def test_endpoint_returns_endpoint_object
    stub_get "/v1/sandboxes/sb-abc/endpoints/8080",
             { "endpoint" => "sb-abc.sandbox.local:8080", "headers" => {} },
             query: { "useServerProxy" => "false" }
    ep = @client.sandboxes.endpoint("sb-abc", port: 8080)
    assert_instance_of OpenSandbox::Endpoint, ep
    assert_match "sb-abc.sandbox.local", ep.url
  end

  # ── wait_until ────────────────────────────────────────────────────────────

  def test_wait_until_returns_when_target_reached
    # First call returns Pending, second returns Running
    stub_request(:get, "#{BASE}/v1/sandboxes/sb-abc")
      .to_return(
        { status: 200, body: sandbox_payload("Pending").to_json, headers: json_header },
        { status: 200, body: sandbox_payload("Running").to_json, headers: json_header }
      )
    sb = @client.sandboxes.wait_until("sb-abc", target_state: "Running", interval: 0)
    assert sb.status.running?
  end

  def test_wait_until_raises_on_failed_state
    stub_request(:get, "#{BASE}/v1/sandboxes/sb-abc")
      .to_return(status: 200, body: sandbox_payload("Failed", message: "OOMKilled").to_json, headers: json_header)
    assert_raises(OpenSandbox::Error) do
      @client.sandboxes.wait_until("sb-abc", target_state: "Running", interval: 0)
    end
  end

  def test_wait_until_raises_on_timeout
    stub_request(:get, "#{BASE}/v1/sandboxes/sb-abc")
      .to_return(status: 200, body: sandbox_payload("Pending").to_json, headers: json_header)
    assert_raises(OpenSandbox::Error) do
      @client.sandboxes.wait_until("sb-abc", target_state: "Running", timeout: 0, interval: 0)
    end
  end

  # ── error mapping ─────────────────────────────────────────────────────────

  def test_401_raises_authentication_error
    stub_request(:get, "#{BASE}/v1/sandboxes/sb-abc")
      .to_return(status: 401, body: '{"message":"unauthorized"}', headers: json_header)
    assert_raises(OpenSandbox::AuthenticationError) { @client.sandboxes.get("sb-abc") }
  end

  def test_409_raises_conflict_error
    stub_request(:post, "#{BASE}/v1/sandboxes")
      .to_return(status: 409, body: '{"message":"conflict"}', headers: json_header)
    assert_raises(OpenSandbox::ConflictError) do
      @client.sandboxes.create(image: "x", entrypoint: ["cmd"], resource_limits: {})
    end
  end

  def test_500_raises_server_error
    stub_request(:get, "#{BASE}/v1/sandboxes/sb-abc")
      .to_return(status: 500, body: '{"message":"internal"}', headers: json_header)
    assert_raises(OpenSandbox::ServerError) { @client.sandboxes.get("sb-abc") }
  end

  private

  def json_header = { "Content-Type" => "application/json" }

  def stub_get(path, body, query: {})
    req = stub_request(:get, "#{BASE}#{path}")
    req = req.with(query: query) if query.any?
    req.to_return(status: 200, body: body.to_json, headers: json_header)
  end

  def sandbox_payload(state = "Running", message: nil)
    {
      "id"         => "sb-abc",
      "image"      => { "uri" => "python:3.11-slim" },
      "status"     => { "state" => state, "message" => message },
      "entrypoint" => ["python", "-c", "print(1)"],
      "metadata"   => {},
      "expiresAt"  => nil,
      "createdAt"  => "2025-01-01T00:00:00Z"
    }
  end

  def list_response(items)
    {
      "items"      => items,
      "pagination" => { "page" => 1, "pageSize" => 20,
                        "totalItems" => items.length, "totalPages" => 1, "hasNextPage" => false }
    }
  end
end

class PoolsTest < Minitest::Test
  BASE = "http://localhost:8787"

  def setup
    @client = OpenSandbox::Client.new(base_url: BASE)
  end

  def test_list_pools
    stub_request(:get, "#{BASE}/v1/pools")
      .to_return(status: 200, body: { "items" => [pool_payload] }.to_json, headers: json_header)
    pools = @client.pools.list
    assert_equal 1, pools.length
    assert_equal "my-pool", pools.first.name
  end

  def test_get_pool
    stub_request(:get, "#{BASE}/v1/pools/my-pool")
      .to_return(status: 200, body: pool_payload.to_json, headers: json_header)
    pool = @client.pools.get("my-pool")
    assert_equal "my-pool", pool.name
    assert_equal 5, pool.capacity_spec.buffer_max
  end

  def test_delete_pool
    stub_request(:delete, "#{BASE}/v1/pools/my-pool")
      .to_return(status: 204, body: "")
    assert_nil @client.pools.delete("my-pool")
  end

  private

  def json_header = { "Content-Type" => "application/json" }

  def pool_payload
    {
      "name"         => "my-pool",
      "capacitySpec" => { "bufferMax" => 5, "bufferMin" => 1, "poolMax" => 10, "poolMin" => 2 },
      "status"       => nil,
      "createdAt"    => "2025-01-01T00:00:00Z"
    }
  end
end

class HealthTest < Minitest::Test
  BASE = "http://localhost:8787"

  def test_healthy_returns_true_on_200
    stub_request(:get, "#{BASE}/health")
      .to_return(status: 200, body: '{"status":"ok"}', headers: { "Content-Type" => "application/json" })
    assert OpenSandbox::Client.new(base_url: BASE).healthy?
  end

  def test_healthy_returns_false_on_error
    stub_request(:get, "#{BASE}/health").to_return(status: 500, body: "err")
    refute OpenSandbox::Client.new(base_url: BASE).healthy?
  end

  def test_healthy_returns_false_on_connection_error
    stub_request(:get, "#{BASE}/health").to_raise(SocketError)
    refute OpenSandbox::Client.new(base_url: BASE).healthy?
  end
end
