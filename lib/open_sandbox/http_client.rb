# frozen_string_literal: true

require "json"
require "httparty"

module OpenSandbox
  # Low-level HTTP client for the OpenSandbox API.
  # Not intended to be used directly – use Client instead.
  class HttpClient
    include HTTParty

    DEFAULT_TIMEOUT = 30
    DEFAULT_OPEN_TIMEOUT = 10

    attr_reader :base_url, :api_key, :timeout

    def initialize(base_url:, api_key: nil, timeout: DEFAULT_TIMEOUT)
      @base_url     = base_url.chomp("/")
      @api_key      = api_key
      @timeout      = timeout
    end

    def get(path, query: {}, headers: {})
      request(:get, path, query: query.compact, headers: headers)
    end

    def post(path, body: {}, headers: {})
      request(:post, path, body: body, headers: headers)
    end

    def put(path, body: {}, headers: {})
      request(:put, path, body: body, headers: headers)
    end

    def delete(path, headers: {})
      request(:delete, path, headers: headers)
    end

    # Proxy raw HTTP request to sandbox internal service
    # Returns the raw HTTParty response
    def proxy(method, path, body: nil, headers: {})
      request(method, path, body: body, headers: headers, raw: true)
    end

    private

    def request(method, path, query: {}, body: nil, headers: {}, raw: false)
      url = "#{base_url}#{path}"
      options = {
        timeout:      timeout,
        open_timeout: DEFAULT_OPEN_TIMEOUT,
        headers:      build_headers(headers)
      }
      options[:query] = query if query && !query.empty?

      if body
        options[:body]    = body.to_json
        options[:headers] = (options[:headers] || {}).merge("Content-Type" => "application/json")
      end

      response = self.class.send(method, url, options)

      return response if raw
      handle_response(response)
    rescue ::Net::OpenTimeout, ::Net::ReadTimeout => e
      raise ConnectionError, "Request timed out: #{e.message}"
    rescue ::SocketError, ::Errno::ECONNREFUSED => e
      raise ConnectionError, "Cannot connect to sandbox server at #{base_url}: #{e.message}"
    end

    def build_headers(extra = {})
      headers = { "Accept" => "application/json" }
      headers["Authorization"] = "Bearer #{api_key}" if api_key && !api_key.empty?
      headers.merge(extra)
    end

    def handle_response(response)
      case response.code
      when 200, 201, 202
        parse_json(response)
      when 204
        nil
      when 400
        raise InvalidRequestError, error_message(response)
      when 401
        raise AuthenticationError, error_message(response)
      when 403
        raise ForbiddenError, error_message(response)
      when 404
        raise NotFoundError, error_message(response)
      when 409
        raise ConflictError, error_message(response)
      when 422
        raise ValidationError, error_message(response)
      when 500..599
        raise ServerError, "Server error (#{response.code}): #{error_message(response)}"
      else
        raise Error, "Unexpected status #{response.code}: #{response.body}"
      end
    end

    def parse_json(response)
      body = response.body
      return nil if body.nil? || body.empty?
      JSON.parse(body)
    rescue JSON::ParserError
      response.body
    end

    def error_message(response)
      data = parse_json(response)
      if data.is_a?(Hash)
        data["message"] || data["detail"] || response.body
      else
        response.body
      end
    rescue
      response.body
    end
  end
end
