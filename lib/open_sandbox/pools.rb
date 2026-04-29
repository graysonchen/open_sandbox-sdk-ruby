# frozen_string_literal: true

module OpenSandbox
  # Manages pre-warmed resource pools for reduced sandbox cold-start latency.
  class Pools
    def initialize(http)
      @http = http
    end

    # List all pools.
    #
    # @return [Array<Pool>]
    def list
      data = @http.get("/v1/pools")
      (data["items"] || []).map { Pool.from_hash(_1) }
    end

    # Get a pool by name.
    #
    # @param pool_name [String]
    # @return [Pool]
    # @raise [NotFoundError]
    def get(pool_name)
      Pool.from_hash(@http.get("/v1/pools/#{pool_name}"))
    end

    # Create a new pre-warmed pool.
    #
    # @param name [String] unique pool name (lowercase alphanumeric + hyphens)
    # @param template [Hash] Kubernetes PodTemplateSpec
    # @param capacity_spec [PoolCapacitySpec, Hash] capacity configuration
    # @return [Pool]
    def create(name:, template:, capacity_spec:)
      spec = capacity_spec.is_a?(PoolCapacitySpec) ? capacity_spec.to_api_hash : capacity_spec.transform_keys(&:to_s).then do |h|
        {
          "bufferMax" => h["buffer_max"] || h["bufferMax"],
          "bufferMin" => h["buffer_min"] || h["bufferMin"],
          "poolMax"   => h["pool_max"]   || h["poolMax"],
          "poolMin"   => h["pool_min"]   || h["poolMin"]
        }
      end

      body = { "name" => name.to_s, "template" => template, "capacitySpec" => spec }
      Pool.from_hash(@http.post("/v1/pools", body: body))
    end

    # Update pool capacity configuration.
    #
    # @param pool_name [String]
    # @param capacity_spec [PoolCapacitySpec, Hash]
    # @return [Pool]
    def update(pool_name, capacity_spec:)
      spec = capacity_spec.is_a?(PoolCapacitySpec) ? capacity_spec.to_api_hash : capacity_spec
      body = { "capacitySpec" => spec }
      Pool.from_hash(@http.put("/v1/pools/#{pool_name}", body: body))
    end

    # Delete a pool.
    #
    # @param pool_name [String]
    # @return [nil]
    def delete(pool_name)
      @http.delete("/v1/pools/#{pool_name}")
    end
  end
end
