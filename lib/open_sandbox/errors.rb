# frozen_string_literal: true

module OpenSandbox
  # Base error for all OpenSandbox errors
  class Error < StandardError; end

  # 400 - Invalid request
  class InvalidRequestError < Error; end

  # 401 - Missing or invalid credentials
  class AuthenticationError < Error; end

  # 403 - Insufficient permissions
  class ForbiddenError < Error; end

  # 404 - Resource not found
  class NotFoundError < Error; end

  # 409 - Conflict (e.g., already exists, wrong state)
  class ConflictError < Error; end

  # 422 - Validation error
  class ValidationError < Error; end

  # 500 - Server error
  class ServerError < Error; end

  # Connection / timeout errors
  class ConnectionError < Error; end
end
