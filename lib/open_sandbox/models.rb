# frozen_string_literal: true

require "time"

module OpenSandbox
  # Sandbox lifecycle states
  module SandboxState
    PENDING    = "Pending"
    RUNNING    = "Running"
    PAUSING    = "Pausing"
    PAUSED     = "Paused"
    STOPPING   = "Stopping"
    TERMINATED = "Terminated"
    FAILED     = "Failed"
  end

  # Value object for sandbox status
  SandboxStatus = Data.define(:state, :reason, :message, :last_transition_at) do
    def running?   = state == SandboxState::RUNNING
    def pending?   = state == SandboxState::PENDING
    def paused?    = state == SandboxState::PAUSED
    def failed?    = state == SandboxState::FAILED
    def terminated? = state == SandboxState::TERMINATED

    def self.from_hash(h)
      return nil unless h
      new(
        state:              h["state"],
        reason:             h["reason"],
        message:            h["message"],
        last_transition_at: h["lastTransitionAt"] ? Time.parse(h["lastTransitionAt"]) : nil
      )
    end
  end

  # Value object for a Sandbox resource
  Sandbox = Data.define(:id, :status, :image_uri, :entrypoint, :metadata, :expires_at, :created_at) do
    def self.from_hash(h)
      new(
        id:         h["id"],
        status:     SandboxStatus.from_hash(h["status"]),
        image_uri:  h.dig("image", "uri"),
        entrypoint: h["entrypoint"] || [],
        metadata:   h["metadata"] || {},
        expires_at: h["expiresAt"] ? Time.parse(h["expiresAt"]) : nil,
        created_at: h["createdAt"] ? Time.parse(h["createdAt"]) : nil
      )
    end
  end

  # Value object for an Endpoint
  Endpoint = Data.define(:endpoint, :headers) do
    def self.from_hash(h)
      new(endpoint: h["endpoint"], headers: h["headers"] || {})
    end

    def url = endpoint.start_with?("http") ? endpoint : "http://#{endpoint}"
  end

  # Value object for pagination
  PaginationInfo = Data.define(:page, :page_size, :total_items, :total_pages, :has_next_page) do
    def self.from_hash(h)
      new(
        page:          h["page"],
        page_size:     h["pageSize"],
        total_items:   h["totalItems"],
        total_pages:   h["totalPages"],
        has_next_page: h["hasNextPage"]
      )
    end
  end

  # Value object for list response
  SandboxList = Data.define(:items, :pagination) do
    def self.from_hash(h)
      new(
        items:      (h["items"] || []).map { Sandbox.from_hash(_1) },
        pagination: PaginationInfo.from_hash(h["pagination"])
      )
    end
  end

  # Value object for pool capacity
  PoolCapacitySpec = Data.define(:buffer_max, :buffer_min, :pool_max, :pool_min) do
    def self.from_hash(h)
      new(
        buffer_max: h["bufferMax"],
        buffer_min: h["bufferMin"],
        pool_max:   h["poolMax"],
        pool_min:   h["poolMin"]
      )
    end

    def to_api_hash
      { "bufferMax" => buffer_max, "bufferMin" => buffer_min, "poolMax" => pool_max, "poolMin" => pool_min }
    end
  end

  # Value object for a Pool resource
  Pool = Data.define(:name, :capacity_spec, :status, :created_at) do
    def self.from_hash(h)
      new(
        name:          h["name"],
        capacity_spec: PoolCapacitySpec.from_hash(h["capacitySpec"]),
        status:        h["status"],
        created_at:    h["createdAt"] ? Time.parse(h["createdAt"]) : nil
      )
    end
  end

  # Utility helpers for processing sandbox output.
  module LogUtils
    # Strip Docker-style RFC3339 nanosecond timestamp prefixes from each log line.
    #
    #   "2026-04-29T13:37:33.993340334Z 1024\n"  =>  "1024\n"
    #   "no-timestamp\n"                         =>  "no-timestamp\n"
    #
    TIMESTAMP_RE = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z /.freeze

    def self.strip_timestamps(raw)
      raw.to_s.lines.map { |line| line.sub(TIMESTAMP_RE, "") }.join
    end
  end
end
