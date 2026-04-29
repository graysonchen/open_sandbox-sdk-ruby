# frozen_string_literal: true

require "test_helper"

class ModelsTest < Minitest::Test
  # ── SandboxStatus ──────────────────────────────────────────────────────────

  def test_sandbox_status_predicates
    assert make_status("Running").running?
    assert make_status("Pending").pending?
    assert make_status("Paused").paused?
    assert make_status("Failed").failed?
    assert make_status("Terminated").terminated?
    refute make_status("Running").failed?
  end

  def test_sandbox_status_from_hash_parses_transition_time
    h = { "state" => "Running", "reason" => "Started", "message" => "ok",
          "lastTransitionAt" => "2025-06-01T10:00:00Z" }
    status = OpenSandbox::SandboxStatus.from_hash(h)
    assert_equal "Running", status.state
    assert_instance_of Time, status.last_transition_at
  end

  def test_sandbox_status_from_hash_nil_transition_time
    status = OpenSandbox::SandboxStatus.from_hash({ "state" => "Pending" })
    assert_nil status.last_transition_at
  end

  # ── Sandbox ────────────────────────────────────────────────────────────────

  def test_sandbox_from_hash
    sb = OpenSandbox::Sandbox.from_hash(sandbox_hash)
    assert_equal "sb-001",          sb.id
    assert_equal "python:3.11-slim", sb.image_uri
    assert sb.status.running?
    assert_equal "test",            sb.metadata["env"]
    assert_instance_of Time,        sb.created_at
  end

  def test_sandbox_from_hash_nil_expires
    sb = OpenSandbox::Sandbox.from_hash(sandbox_hash.merge("expiresAt" => nil))
    assert_nil sb.expires_at
  end

  # ── Endpoint ───────────────────────────────────────────────────────────────

  def test_endpoint_url_adds_http_prefix
    ep = OpenSandbox::Endpoint.new(endpoint: "localhost:8080", headers: {})
    assert_equal "http://localhost:8080", ep.url
  end

  def test_endpoint_url_preserves_existing_scheme
    ep = OpenSandbox::Endpoint.new(endpoint: "https://sb.example.com", headers: {})
    assert_equal "https://sb.example.com", ep.url
  end

  # ── PoolCapacitySpec ───────────────────────────────────────────────────────

  def test_pool_capacity_spec_to_api_hash
    spec = OpenSandbox::PoolCapacitySpec.new(buffer_max: 5, buffer_min: 1, pool_max: 10, pool_min: 2)
    h = spec.to_api_hash
    assert_equal({ "bufferMax" => 5, "bufferMin" => 1, "poolMax" => 10, "poolMin" => 2 }, h)
  end

  def test_pool_capacity_spec_from_hash
    spec = OpenSandbox::PoolCapacitySpec.from_hash("bufferMax" => 3, "bufferMin" => 0, "poolMax" => 8, "poolMin" => 1)
    assert_equal 3, spec.buffer_max
    assert_equal 8, spec.pool_max
  end

  # ── SandboxList ────────────────────────────────────────────────────────────

  def test_sandbox_list_from_hash
    data = {
      "items"      => [ sandbox_hash, sandbox_hash.merge("id" => "sb-002") ],
      "pagination" => { "page" => 1, "pageSize" => 20, "totalItems" => 2, "totalPages" => 1, "hasNextPage" => false }
    }
    list = OpenSandbox::SandboxList.from_hash(data)
    assert_equal 2,     list.items.length
    assert_equal 2,     list.pagination.total_items
    refute list.pagination.has_next_page
  end

  private

  def make_status(state)
    OpenSandbox::SandboxStatus.new(state: state, reason: nil, message: nil, last_transition_at: nil)
  end

  def sandbox_hash
    {
      "id"         => "sb-001",
      "image"      => { "uri" => "python:3.11-slim" },
      "status"     => { "state" => "Running" },
      "entrypoint" => ["python", "-c", "print(1)"],
      "metadata"   => { "env" => "test" },
      "expiresAt"  => "2025-12-31T23:59:59Z",
      "createdAt"  => "2025-01-01T00:00:00Z"
    }
  end
end
